BeforeAll {
    Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'IdentityAtlas.psd1') -Force
}

Describe 'Authentication collection evidence' {
    It 'distinguishes denied failed empty complete malformed and missing responses' {
        InModuleScope IdentityAtlas {
            Mock Invoke-AtlasGraphRequest { @{ Items = @(); Metrics = @{ requestCount = 1; retryCount = 0 } } }
            Mock Invoke-AtlasGraphBatchGet {
                @{
                    Metrics = @{ requestCount = 1; retryCount = 0; logicalRequestCount = 6 }
                    Responses = @(
                        @{ Id = 'auth-0'; StatusCode = 403; ErrorMessage = 'Access denied'; Items = @() }
                        @{ Id = 'auth-1'; StatusCode = 500; ErrorMessage = 'Unavailable'; Items = @() }
                        @{ Id = 'auth-2'; StatusCode = 200; Items = @() }
                        @{ Id = 'auth-3'; StatusCode = 200; Items = @(@{ id = 'method'; '@odata.type' = '#microsoft.graph.fido2AuthenticationMethod' }) }
                        @{ Id = 'auth-4'; StatusCode = 200; Items = @(@{ '@odata.type' = '#microsoft.graph.fido2AuthenticationMethod' }) }
                    )
                }
            }
            $users = @(0..5 | ForEach-Object { New-AtlasNode -TenantId 'test' -Id "u$_" -Kind user -DisplayName "User $_" })
            $result = Get-AtlasDeviceAndAuthentication -TenantId 'test' -KnownNode $users
            $states = @('accessDenied', 'failed', 'empty', 'complete', 'partial', 'notCollected')
            for ($i = 0; $i -lt 6; $i++) { $result.Metrics.authenticationByUser[$users[$i].Key].status | Should -Be $states[$i] }
            $result.Metrics.authenticationByUser[$users[3].Key].methodCount | Should -Be 1
            $result.Metrics.authenticationByUser[$users[0].Key].statusCode | Should -Be 403
            $result.Edges.Count | Should -Be 1
            $result.Status | Should -Be 'partial'
        }
    }

    It 'records skipped authentication and never requests methods' {
        InModuleScope IdentityAtlas {
            Mock Invoke-AtlasGraphRequest { @{ Items = @(); Metrics = @{ requestCount = 1; retryCount = 0 } } }
            Mock Invoke-AtlasGraphBatchGet { throw 'Must not run' }
            $user = New-AtlasNode -TenantId test -Id u -Kind user -DisplayName User
            $result = Get-AtlasDeviceAndAuthentication -TenantId test -KnownNode @($user) -SkipAuthenticationMethods
            $result.Metrics.authenticationByUser[$user.Key].status | Should -Be 'skipped'
            Should -Invoke Invoke-AtlasGraphBatchGet -Times 0
        }
    }

    It 'preserves per-user coverage through a completed checkpoint' {
        InModuleScope IdentityAtlas -Parameters @{ Root = $TestDrive } {
            param($Root)
            Mock Invoke-AtlasGraphRequest { @{ Items = @(); Metrics = @{ requestCount = 1; retryCount = 0 } } }
            Mock Invoke-AtlasGraphBatchGet { @{ Metrics = @{ requestCount = 1; retryCount = 0; logicalRequestCount = 1 }; Responses = @(@{ Id = 'auth-0'; StatusCode = 200; Items = @() }) } }
            $user = New-AtlasNode -TenantId test -Id u -Kind user -DisplayName User
            $result = Get-AtlasDeviceAndAuthentication -TenantId test -KnownNode @($user)
            try {
                $identity = @{ tenant = 'test' }
                Initialize-AtlasCheckpoint -Path (Join-Path $Root 'auth.checkpoint') -Identity $identity
                Save-AtlasCheckpointResult -Name devicesAndAuthentication -Result $result
                Initialize-AtlasCheckpoint -Path (Join-Path $Root 'auth.checkpoint') -Identity $identity -Resume
                $restored = Get-AtlasCheckpointResult -Name devicesAndAuthentication
                $restored.Metrics.authenticationByUser[$user.Key].status | Should -Be 'empty'
                ([datetime]$restored.Metrics.authenticationByUser[$user.Key].observedAtUtc).ToUniversalTime() | Should -Be ([datetime]$result.Metrics.authenticationByUser[$user.Key].observedAtUtc).ToUniversalTime()
            }
            finally { $script:AtlasCheckpoint = $null }
        }
    }
}

Describe 'Progress and completion guidance' {
    It 'clears progress and checkpoint state when PowerShell stops the pipeline itself' {
        $modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'IdentityAtlas.psd1'
        $output = Join-Path $TestDrive 'pipeline-stop'
        $runspace = [runspacefactory]::CreateRunspace($Host)
        $runspace.Open()
        $pipeline = [powershell]::Create()
        $pipeline.Runspace = $runspace
        try {
            $null = $pipeline.AddScript({
                param($ModulePath, $OutputPath)
                Import-Module $ModulePath -Force
                & (Get-Module IdentityAtlas) {
                    function script:Get-MgContext { @{ TenantId = 'test'; Account = 'test'; ClientId = 'test'; Scopes = @(Get-AtlasRecommendedScope) } }
                    function script:Get-AtlasUser { [AtlasCollectionResult]::new() }
                    function script:Get-AtlasGroup { Start-Sleep -Seconds 30; throw 'The test failed to stop this collector.' }
                }
                Invoke-IdentityAtlas -OutputPath $OutputPath -CollectionProfile Core -Checkpoint
            }).AddArgument($modulePath).AddArgument($output)
            $invocation = $pipeline.BeginInvoke()
            $deadline = [datetime]::UtcNow.AddSeconds(10)
            while (-not (Test-Path -LiteralPath "$output.checkpoint/users.json") -and -not $invocation.IsCompleted -and [datetime]::UtcNow -lt $deadline) {
                Start-Sleep -Milliseconds 50
            }
            Test-Path -LiteralPath "$output.checkpoint/users.json" | Should -BeTrue
            $pipeline.Stop()
            try { $null = $pipeline.EndInvoke($invocation) } catch [System.Management.Automation.PipelineStoppedException] { Write-Verbose 'Expected pipeline stop received.' }
            $pipeline.InvocationStateInfo.State.ToString() | Should -Be Stopped
            Test-Path -LiteralPath "$output/index.html" | Should -BeFalse
            $pipeline.Commands.Clear()
            $null = $pipeline.AddScript({ & (Get-Module IdentityAtlas) {
                [pscustomobject]@{ ProgressCleared = $null -eq $script:IdentityAtlasProgressContext; CheckpointCleared = $null -eq $script:AtlasCheckpoint }
            } })
            $state = @($pipeline.Invoke())[0]
            $state.ProgressCleared | Should -BeTrue
            $state.CheckpointCleared | Should -BeTrue
        }
        finally { $pipeline.Dispose(); $runspace.Dispose() }
    }

    It 'resumes after cancellation without repeating a completed collector or returning an unfinished report' {
        InModuleScope IdentityAtlas -Parameters @{ Root = $TestDrive } {
            param($Root)
            $script:cancelGroupTest = $true
            Mock Get-MgContext { @{ TenantId = 'test'; Account = 'test'; ClientId = 'test'; Scopes = @(Get-AtlasRecommendedScope) } }
            Mock Get-AtlasUser {
                $result = [AtlasCollectionResult]::new()
                $result.Nodes.Add((New-AtlasNode -TenantId test -Id u -Kind user -DisplayName User))
                $result
            }
            Mock Get-AtlasGroup {
                if ($script:cancelGroupTest) { throw [System.OperationCanceledException]::new('Cancelled test') }
                [AtlasCollectionResult]::new()
            }
            Mock Get-AtlasDeviceAndAuthentication { [AtlasCollectionResult]::new() }
            Mock Get-AtlasDirectoryRole { [AtlasCollectionResult]::new() }
            Mock Get-AtlasApplication { [AtlasCollectionResult]::new() }
            Mock Get-AtlasApplicationManagementPolicy { [AtlasCollectionResult]::new() }
            Mock Get-AtlasCrossTenantAccess { [AtlasCollectionResult]::new() }
            Mock Get-AtlasConditionalAccessPolicy { [AtlasCollectionResult]::new() }
            Mock Get-AtlasConditionalAccessReference { [AtlasCollectionResult]::new() }
            $output = Join-Path $Root 'resume-report'
            try {
                { Invoke-IdentityAtlas -OutputPath $output -CollectionProfile Core -Checkpoint } | Should -Throw '*Cancelled test*'
                Test-Path -LiteralPath (Join-Path $output 'index.html') | Should -BeFalse
                Test-Path -LiteralPath (Join-Path "$output.checkpoint" 'users.json') | Should -BeTrue
                Test-Path -LiteralPath (Join-Path "$output.checkpoint" 'groups.json') | Should -BeFalse
                $script:cancelGroupTest = $false
                $resumed = Invoke-IdentityAtlas -OutputPath $output -CollectionProfile Core -Resume
                $resumed.NodeCount | Should -Be 1
                $resumed.CoverageStatus | Should -Be partial
                $resumed.ReopenCommand | Should -Match '^Open-IdentityAtlasReport -Path '
                $saved = Get-Content -LiteralPath (Join-Path $output 'data/report.json') -Raw | ConvertFrom-Json
                $saved.manifest.resumedCollectors | Should -Contain users
                Should -Invoke Get-AtlasUser -Times 1 -Exactly
                Should -Invoke Get-AtlasGroup -Times 2 -Exactly
            }
            finally { $script:AtlasCheckpoint = $null; $script:cancelGroupTest = $false }
        }
    }

    It 'retains timed progress messages without logging every request' {
        InModuleScope IdentityAtlas {
            Mock Write-Information {}
            Mock Write-Progress {}
            try {
                $context = Initialize-AtlasProgress -StepCount 1 -CollectionProfile Governance
                Start-AtlasProgressStep -Name pimGroups -DisplayName 'PIM groups' -Step 1
                $context.LastInformationMilliseconds = $context.Stopwatch.ElapsedMilliseconds
                Update-AtlasProgressItem -CurrentItem 1 -TotalItems 10 -Status 'PIM groups | Failed requests 0'
                Should -Invoke Write-Information -Times 0 -ParameterFilter { $MessageData -like '*Items 1/10*' }
                $context.LastInformationMilliseconds = -5001
                Update-AtlasProgressRequest -RequestIncrement 1
                Should -Invoke Write-Information -Times 1 -ParameterFilter { $MessageData -like '*Items 1/10*' }
                Update-AtlasProgressItem -CurrentItem 10 -TotalItems 10 -Status 'PIM groups' -FailedRequestCount 2
                Should -Invoke Write-Information -Times 1 -ParameterFilter { $MessageData -like '*Items 10/10*Failed requests 2*' }
                Update-AtlasProgressRequest -RequestIncrement 1 -Status 'Requesting Microsoft Graph'
                Get-AtlasProgressStatus | Should -Match 'Failed requests 2'
            }
            finally { [void](Complete-AtlasProgress) }
        }
    }

    It 'reports checked PIM groups and failed requests' {
        InModuleScope IdentityAtlas {
            Mock Update-AtlasProgressItem {}
            Mock Invoke-AtlasGraphRequest {
                if ($Uri -like '*eligibilityScheduleInstances*') { throw 'Unavailable' }
                @{ Items = @(); Metrics = @{ requestCount = 1; retryCount = 0 } }
            }
            $groups = @(1..2 | ForEach-Object { New-AtlasNode -TenantId test -Id "g$_" -Kind group -DisplayName "Group $_" })
            $result = Get-AtlasPrivilegedGroupAssignment -TenantId test -KnownNode $groups
            $result.Metrics.failedRequestCount | Should -Be 2
            $result.Status | Should -Be partial
            Should -Invoke Update-AtlasProgressItem -Times 1 -ParameterFilter { $CurrentItem -eq 2 -and $TotalItems -eq 2 -and $FailedRequestCount -eq 2 }
        }
    }

    It 'does not swallow a PIM cancellation as partial coverage' {
        InModuleScope IdentityAtlas {
            Mock Invoke-AtlasGraphRequest { throw [System.OperationCanceledException]::new('Cancelled test') }
            $group = New-AtlasNode -TenantId test -Id g -Kind group -DisplayName Group
            { Get-AtlasPrivilegedGroupAssignment -TenantId test -KnownNode @($group) } | Should -Throw '*Cancelled test*'
        }
    }

    It 'summarises incomplete coverage and safely quotes the reopen path' {
        InModuleScope IdentityAtlas {
            $report = @{ manifest = @{ coverage = @{ status = 'partial'; warnings = @('Denied'); collectors = @(
                @{ name = 'users'; status = 'complete' }, @{ name = 'devicesAndAuthentication'; status = 'partial' }, @{ name = 'permissionPreflight'; status = 'partial' }
            ) } } }
            $summary = Get-AtlasCompletionSummary -Report $report -ReportPath "C:\Reports\User's report" -SkippedCollector AuthenticationMethods
            $summary.CompleteCollectors | Should -Contain users
            $summary.IncompleteCollectors | Should -Contain devicesAndAuthentication
            $summary.ReopenCommand | Should -Be "Open-IdentityAtlasReport -Path 'C:\Reports\User''s report'"
            ($summary.NextActions -join ' ') | Should -Match 'Access denied remains unknown'
            $summary.WarningCount | Should -Be 1
        }
    }
}

Describe 'Optional delegated consent preflight' {
    It 'requires consent read permission only when opted in for either profile' -TestCases @(@{ CollectionProfile = 'Core' }, @{ CollectionProfile = 'Governance' }) {
        param($CollectionProfile)
        InModuleScope IdentityAtlas -Parameters @{ CollectionProfile = $CollectionProfile } {
            param($CollectionProfile)
            $scopes = Get-AtlasRecommendedScope -CollectionProfile $CollectionProfile
            (Get-AtlasPermissionAssessment -ContextScope $scopes -CollectionProfile $CollectionProfile).status | Should -Be complete
            $missing = Get-AtlasPermissionAssessment -ContextScope $scopes -CollectionProfile $CollectionProfile -IncludeConsent
            $missing.status | Should -Be partial
            $missing.missingRequirements.collector | Should -Contain delegatedConsent
            $allowed = Get-AtlasPermissionAssessment -ContextScope ($scopes + 'Directory.Read.All') -CollectionProfile $CollectionProfile -IncludeConsent
            $allowed.status | Should -Be complete
            $allowed.endpointAccess | Should -Be unverified
            $preflight = New-AtlasPermissionPreflightResult -ContextScope $scopes -CollectionProfile $CollectionProfile -IncludeConsent
            $preflight.Metrics.includeConsent | Should -BeTrue
            $preflight.Metrics.missingScopes | Should -Contain 'Directory.Read.All'
        }
    }

    It 'checks IncludeConsent through the public connection command without calling Graph' {
        InModuleScope IdentityAtlas {
            Mock Get-MgContext { @{ TenantId = 'test'; Account = 'test'; AuthType = 'Delegated'; Scopes = @(Get-AtlasRecommendedScope) } }
            Mock Invoke-AtlasGraphRequest { throw 'Must not collect' }
            $result = Test-IdentityAtlasConnection -IncludeConsent
            $result.PermissionStatus | Should -Be partial
            $result.EndpointAccess | Should -Be unverified
            $result.MissingScopes | Should -Contain 'Directory.Read.All'
            Should -Invoke Invoke-AtlasGraphRequest -Times 0
        }
    }
}
