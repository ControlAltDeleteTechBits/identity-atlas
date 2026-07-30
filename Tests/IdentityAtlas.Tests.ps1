$discoveryProjectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $discoveryProjectRoot 'IdentityAtlas.psd1') -Force

Describe 'Identity Atlas isolated test fixture' {
    BeforeAll {
        $projectRoot = Split-Path -Parent $PSScriptRoot
        $modulePath = Join-Path $projectRoot 'IdentityAtlas.psd1'
        $fixturePath = Join-Path $PSScriptRoot 'Fixtures/Get-AtlasTestData.ps1'
        $script:identityAtlasModule = Import-Module $modulePath -Force -PassThru

        function New-IdentityAtlasTestReport {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                'PSUseShouldProcessForStateChangingFunctions',
                '',
                Justification = 'Writes only to the Pester TestDrive or a deliberately rejected source-path test.'
            )]
            param(
                [Parameter(Mandatory)]
                [string] $OutputPath
            )

            & $script:identityAtlasModule {
                param($TestFixturePath, $TestOutputPath)

                . $TestFixturePath
                $fixture = Get-AtlasTestData
                $report = New-AtlasReport -TenantId $fixture.TenantId -TenantDisplayName $fixture.TenantDisplayName -Collection $fixture.Collection -Collectors $fixture.Collectors -DataOrigin SampleFixture
                $indexFile = Write-AtlasReport -Report $report -OutputPath $TestOutputPath
                [pscustomobject] @{
                    OutputPath = $indexFile.DirectoryName
                    IndexPath = $indexFile.FullName
                    NodeCount = $report.manifest.counts.nodes
                    EdgeCount = $report.manifest.counts.edges
                    EvidenceCount = $report.manifest.counts.evidence
                    CoverageStatus = $report.manifest.coverage.status
                }
            } $fixturePath $OutputPath
        }

        $script:reportPath = Join-Path $TestDrive 'SampleReport'
        $script:result = New-IdentityAtlasTestReport -OutputPath $script:reportPath
        $script:report = Get-Content -Raw -LiteralPath (Join-Path $script:reportPath 'data/report.json') |
            ConvertFrom-Json
    }

    It 'exports the four public commands' {
        $commands = Get-Command -Module IdentityAtlas | Select-Object -ExpandProperty Name
        $commands.Count | Should -Be 4
        ($commands -contains 'Connect-IdentityAtlas') | Should -Be $true
        ($commands -contains 'Invoke-IdentityAtlas') | Should -Be $true
        ($commands -contains 'Export-IdentityAtlas') | Should -Be $true
        ($commands -contains 'Compare-IdentityAtlas') | Should -Be $true
        (Get-Command Invoke-IdentityAtlas).Parameters.ContainsKey('SampleData') | Should -Be $false
    }

    It 'creates a complete offline report package' {
        Test-Path -LiteralPath (Join-Path $script:reportPath 'index.html') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $script:reportPath 'assets/app.js') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $script:reportPath 'data/nodes-0001.js') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $script:reportPath '.identity-atlas-report.json') | Should -Be $true
        $script:result.CoverageStatus | Should -Be 'complete'
    }

    It 'records read-only security metadata without serialising tokens' {
        $script:report.manifest.schemaVersion | Should -Be '1.1.0'
        $script:report.manifest.reportVersion | Should -Be '0.14.0'
        $script:report.manifest.security.readOnlyCollection | Should -Be $true
        $script:report.manifest.security.tokenDataSerialized | Should -Be $false
        $script:report.manifest.security.browserNetworkAccess | Should -Be 'disabled'
        $script:report.manifest.security.localServerBinding | Should -Be 'loopbackOnly'
        $script:report.manifest.security.containsTenantData | Should -Be $false

        $reportText = Get-Content -LiteralPath (Join-Path $script:reportPath 'data/report.json') -Raw
        $reportText | Should -Not -Match '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]+'
        $reportText | Should -Not -Match '(?i)"(access_token|client_secret|secretText|password)"\s*:'
    }

    It 'uses a restrictive offline content security policy' {
        $indexText = Get-Content -LiteralPath (Join-Path $script:reportPath 'index.html') -Raw
        $indexText | Should -Match "default-src 'none'"
        $indexText | Should -Match "connect-src 'none'"
        $indexText | Should -Match "script-src 'self'"
        $indexText | Should -Match 'name="referrer" content="no-referrer"'
    }

    It 'uses the Identity Atlas brand throughout the distributable browser package' {
        $indexText = Get-Content -LiteralPath (Join-Path $script:reportPath 'index.html') -Raw
        $appText = Get-Content -LiteralPath (Join-Path $script:reportPath 'assets/app.js') -Raw
        $runtimeText = Get-Content -LiteralPath (Join-Path $script:reportPath 'assets/data-runtime.js') -Raw
        $manifestText = Get-Content -LiteralPath (Join-Path $script:reportPath 'data/manifest.js') -Raw

        $indexText | Should -Match '<title>Identity Atlas</title>'
        $indexText | Should -Match 'identity-atlas-logo\.svg'
        $appText | Should -Match 'IdentityAtlasData'
        $runtimeText | Should -Match 'IdentityAtlasData'
        $manifestText | Should -Match '^window\.IdentityAtlasData\.registerManifest'
        "$indexText`n$appText`n$runtimeText`n$manifestText" | Should -Not -Match '(?i)entra[ -]?atlas'
    }

    It 'reads Settings security guidance from the report manifest' {
        $appText = Get-Content -LiteralPath (Join-Path $script:reportPath 'assets/app.js') -Raw
        $appText | Should -Match 'report\.manifest\.security'
        $appText | Should -Not -Match '(?<!report\.)\bmanifest\.security'
    }

    It 'explains both requirements when Conditional Access policy data is unavailable' {
        $appText = Get-Content -LiteralPath (Join-Path $script:reportPath 'assets/app.js') -Raw
        $appText | Should -Match 'Policy\.Read\.All'
        $appText | Should -Match 'supported Microsoft Entra role'
        $appText | Should -Not -Match 'Identity Atlas v0\.4\.0'
    }

    It 'contains the expected fixture counts' {
        $script:result.NodeCount | Should -Be 16
        $script:result.EdgeCount | Should -Be 21
        $script:result.EvidenceCount | Should -Be 21
    }

    It 'keeps every edge endpoint resolvable' {
        $nodeKeys = @{}
        foreach ($node in $script:report.nodes) {
            $nodeKeys[$node.Key] = $true
        }

        $unresolved = @(
            $script:report.edges |
                Where-Object { -not $nodeKeys.ContainsKey($_.From) -or -not $nodeKeys.ContainsKey($_.To) }
        )
        $unresolved.Count | Should -Be 0
    }

    It 'keeps evidence references resolvable' {
        $evidenceKeys = @{}
        foreach ($evidence in $script:report.evidence) {
            $evidenceKeys[$evidence.Key] = $true
        }

        $missing = @(
            foreach ($edge in $script:report.edges) {
                foreach ($evidenceId in $edge.EvidenceIds) {
                    if (-not $evidenceKeys.ContainsKey($evidenceId)) {
                        $evidenceId
                    }
                }
            }
        )
        $missing.Count | Should -Be 0
    }

    It 'contains the group-based Global Administrator fixture path' {
        $mark = $script:report.nodes | Where-Object DisplayName -eq 'Mark Oldham'
        $group = $script:report.nodes | Where-Object DisplayName -eq 'Privileged Access Operators'
        $role = $script:report.nodes | Where-Object DisplayName -eq 'Global Administrator'
        $membership = $script:report.edges | Where-Object {
            $_.From -eq $mark.Key -and $_.To -eq $group.Key -and $_.Relationship -eq 'memberOf'
        }
        $assignment = $script:report.edges | Where-Object {
            $_.From -eq $group.Key -and $_.To -eq $role.Key -and $_.Relationship -eq 'assignedRole'
        }

        @($membership).Count | Should -Be 1
        @($assignment).Count | Should -Be 1
    }

    It 'contains the direct application app role fixture path' {
        $mark = $script:report.nodes | Where-Object DisplayName -eq 'Mark Oldham'
        $app = $script:report.nodes | Where-Object DisplayName -eq 'Contoso Finance API'
        $assignment = $script:report.edges | Where-Object {
            $_.From -eq $mark.Key -and $_.To -eq $app.Key -and $_.Relationship -eq 'assignedAppRole'
        }

        @($assignment).Count | Should -Be 1
        $assignment.State.appRoleDisplayName | Should -Be 'Finance.Reader'
    }

    It 'contains the Conditional Access policy fixture relationships' {
        $mark = $script:report.nodes | Where-Object DisplayName -eq 'Mark Oldham'
        $app = $script:report.nodes | Where-Object DisplayName -eq 'Contoso Finance API'
        $policy = $script:report.nodes | Where-Object DisplayName -eq 'Require MFA for Finance API'
        $userInclusion = $script:report.edges | Where-Object {
            $_.From -eq $mark.Key -and $_.To -eq $policy.Key -and $_.Relationship -eq 'conditionalAccessIncludes'
        }
        $appInclusion = $script:report.edges | Where-Object {
            $_.From -eq $app.Key -and $_.To -eq $policy.Key -and $_.Relationship -eq 'conditionalAccessIncludes'
        }

        @($userInclusion).Count | Should -Be 1
        @($appInclusion).Count | Should -Be 1
        $policy.Properties.state | Should -Be 'enabled'
    }

    It 'contains application ownership, credential and permission fixture relationships' {
        $mark = $script:report.nodes | Where-Object DisplayName -eq 'Mark Oldham'
        $app = $script:report.nodes | Where-Object DisplayName -eq 'Contoso Finance API registration'
        $credential = $script:report.nodes | Where-Object DisplayName -eq 'Finance API client secret'
        $permission = $script:report.nodes | Where-Object DisplayName -eq 'Microsoft Graph User.Read.All'

        @($script:report.edges | Where-Object {
            $_.From -eq $app.Key -and $_.To -eq $mark.Key -and $_.Relationship -eq 'ownedBy'
        }).Count | Should -Be 1
        @($script:report.edges | Where-Object {
            $_.From -eq $app.Key -and $_.To -eq $credential.Key -and $_.Relationship -eq 'hasCredential'
        }).Count | Should -Be 1
        @($script:report.edges | Where-Object {
            $_.From -eq $app.Key -and $_.To -eq $permission.Key -and $_.Relationship -eq 'requiresApiPermission'
        }).Count | Should -Be 1
    }

    It 'contains device and authentication method fixture relationships' {
        $mark = $script:report.nodes | Where-Object DisplayName -eq 'Mark Oldham'
        $device = $script:report.nodes | Where-Object DisplayName -eq 'MARK-SURFACE-LAPTOP'
        $method = $script:report.nodes | Where-Object Kind -eq 'authenticationMethod'

        @($script:report.edges | Where-Object {
            $_.From -eq $mark.Key -and $_.To -eq $device.Key -and $_.Relationship -eq 'registeredDevice'
        }).Count | Should -Be 1
        @($script:report.edges | Where-Object {
            $_.From -eq $mark.Key -and $_.To -eq $method.Key -and $_.Relationship -eq 'hasAuthenticationMethod'
        }).Count | Should -Be 1
    }

    It 'contains Conditional Access reference fixture relationships' {
        $policy = $script:report.nodes | Where-Object DisplayName -eq 'Require MFA for Finance API'
        $location = $script:report.nodes | Where-Object DisplayName -eq 'Head Office trusted IPs'
        $strength = $script:report.nodes | Where-Object DisplayName -eq 'Phishing-resistant MFA'

        @($script:report.edges | Where-Object {
            $_.From -eq $policy.Key -and $_.To -eq $location.Key -and $_.Relationship -eq 'conditionalAccessIncludesLocation'
        }).Count | Should -Be 1
        @($script:report.edges | Where-Object {
            $_.From -eq $policy.Key -and $_.To -eq $strength.Key -and $_.Relationship -eq 'requiresAuthenticationStrength'
        }).Count | Should -Be 1
    }

    It 'contains the eligible Global Administrator fixture path' {
        $alex = $script:report.nodes | Where-Object DisplayName -eq 'Alex Wilkins'
        $role = $script:report.nodes | Where-Object DisplayName -eq 'Global Administrator'
        $eligibility = $script:report.edges | Where-Object {
            $_.From -eq $alex.Key -and $_.To -eq $role.Key -and $_.Relationship -eq 'eligibleRole'
        }

        @($eligibility).Count | Should -Be 1
        $eligibility.State.activation | Should -Be 'eligible'
    }

    It 'conforms to the versioned JSON schemas' {
        $schemaRoot = Join-Path $projectRoot 'Schema'
        (($script:report.manifest | ConvertTo-Json -Depth 30) |
            Test-Json -SchemaFile (Join-Path $schemaRoot 'atlas-manifest.schema.json')) | Should -Be $true

        foreach ($node in $script:report.nodes) {
            (($node | ConvertTo-Json -Depth 30) |
                Test-Json -SchemaFile (Join-Path $schemaRoot 'atlas-node.schema.json')) | Should -Be $true
        }
        foreach ($edge in $script:report.edges) {
            (($edge | ConvertTo-Json -Depth 30) |
                Test-Json -SchemaFile (Join-Path $schemaRoot 'atlas-edge.schema.json')) | Should -Be $true
        }
        foreach ($evidence in $script:report.evidence) {
            (($evidence | ConvertTo-Json -Depth 30) |
                Test-Json -SchemaFile (Join-Path $schemaRoot 'atlas-evidence.schema.json')) | Should -Be $true
        }
    }

    It 'exports JSON, CSV and Markdown summaries' {
        $exportRoot = Join-Path $TestDrive 'Exports'
        Export-IdentityAtlas -InputObject $script:report -OutputPath (Join-Path $exportRoot 'Json') -Format Json | Out-Null
        Export-IdentityAtlas -InputObject $script:report -OutputPath (Join-Path $exportRoot 'Csv') -Format Csv | Out-Null
        Export-IdentityAtlas -InputObject $script:report -OutputPath (Join-Path $exportRoot 'Markdown') -Format Markdown | Out-Null

        Test-Path -LiteralPath (Join-Path $exportRoot 'Json/report.json') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $exportRoot 'Csv/nodes.csv') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $exportRoot 'Csv/edges.csv') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $exportRoot 'Markdown/report-summary.md') | Should -Be $true
    }

    It 'compares reports and writes JSON plus Markdown output' {
        $referencePath = Join-Path $TestDrive 'ReferenceReport'
        $differencePath = Join-Path $TestDrive 'DifferenceReport'
        New-IdentityAtlasTestReport -OutputPath $referencePath | Out-Null
        New-IdentityAtlasTestReport -OutputPath $differencePath | Out-Null

        $differenceReportPath = Join-Path $differencePath 'data/report.json'
        $differenceReport = Get-Content -Raw -LiteralPath $differenceReportPath | ConvertFrom-Json
        $differenceReport.nodes = @($differenceReport.nodes | Where-Object DisplayName -ne 'Finance API client secret')
        $differenceReport.edges = @($differenceReport.edges | Where-Object Relationship -ne 'hasCredential')
        $policy = $differenceReport.nodes | Where-Object DisplayName -eq 'Require MFA for Finance API'
        $policy.Properties.state = 'disabled'
        $differenceReport.manifest.counts.nodes = $differenceReport.nodes.Count
        $differenceReport.manifest.counts.edges = $differenceReport.edges.Count
        [System.IO.File]::WriteAllText(
            $differenceReportPath,
            ($differenceReport | ConvertTo-Json -Depth 30),
            [System.Text.UTF8Encoding]::new($false)
        )

        $comparisonPath = Join-Path $TestDrive 'Comparison'
        $comparison = Compare-IdentityAtlas -ReferenceReportPath $referencePath -DifferenceReportPath $differencePath -OutputPath $comparisonPath

        $comparison.summary.removedNodes | Should -Be 1
        $comparison.summary.changedNodes | Should -Be 1
        $comparison.summary.removedEdges | Should -Be 1
        Test-Path -LiteralPath (Join-Path $comparisonPath 'comparison.json') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $comparisonPath 'comparison.md') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $comparisonPath 'comparison.html') | Should -Be $true
    }

    It 'refuses to write a report into a project source directory' {
        $unsafePath = Join-Path $projectRoot 'Web/UnsafeReport'
        $threw = $false
        try {
            New-IdentityAtlasTestReport -OutputPath $unsafePath
        }
        catch {
            $threw = $true
        }
        $threw | Should -Be $true
        Test-Path -LiteralPath $unsafePath | Should -Be $false
    }

    InModuleScope IdentityAtlas {
        It 'accepts the recommended delegated scope set' {
            $assessment = Get-AtlasPermissionAssessment -ContextScope @(
                'User.Read.All'
                'UserAuthenticationMethod.Read.All'
                'Group.Read.All'
                'Device.Read.All'
                'Application.Read.All'
                'Policy.Read.All'
                'RoleEligibilitySchedule.Read.Directory'
                'RoleManagement.Read.Directory'
            )

            $assessment.status | Should -Be 'complete'
            $assessment.missingRequirements.Count | Should -Be 0
        }

        It 'summarises complete permission coverage without an empty-property error' {
            $recommendedScopes = @(
                'User.Read.All'
                'UserAuthenticationMethod.Read.All'
                'Group.Read.All'
                'Device.Read.All'
                'Application.Read.All'
                'Policy.Read.All'
                'RoleEligibilitySchedule.Read.Directory'
                'RoleManagement.Read.Directory'
            )

            $preflight = New-AtlasPermissionPreflightResult -ContextScope $recommendedScopes

            $preflight.Status | Should -Be 'complete'
            $preflight.Metrics.missingScopeCount | Should -Be 0
            @($preflight.Metrics.missingScopes).Count | Should -Be 0
            $preflight.Warnings.Count | Should -Be 0
        }

        It 'accepts documented higher privilege alternatives without requesting them by default' {
            $assessment = Get-AtlasPermissionAssessment -ContextScope @(
                'Directory.Read.All'
                'UserAuthenticationMethod.Read.All'
                'Policy.Read.All'
                'RoleManagement.Read.Directory'
            )

            $assessment.status | Should -Be 'complete'
            $assessment.missingRequirements.Count | Should -Be 0
        }

        It 'marks missing delegated scope coverage as partial' {
            $assessment = Get-AtlasPermissionAssessment -ContextScope @('User.Read.All')

            $assessment.status | Should -Be 'partial'
            (@($assessment.missingRequirements.recommended) -contains 'Application.Read.All') | Should -Be $true
            (@($assessment.missingRequirements.recommended) -contains 'Policy.Read.All') | Should -Be $true
        }

        It 'redacts authentication material from collector errors' {
            try {
                throw 'Request failed with Bearer eyJhbGciOiJub25l.secret.signature and access_token=topsecret&code=abc123'
            }
            catch {
                $safeDetail = Get-AtlasSafeErrorDetail -ErrorRecord $_
            }

            $safeDetail | Should -Not -Match 'eyJhbGci'
            $safeDetail | Should -Not -Match 'topsecret'
            $safeDetail | Should -Not -Match 'abc123'
            $safeDetail | Should -Match '\[redacted\]'
        }

        It 'keeps a failed top-level collector as partial coverage' {
            $collector = Invoke-AtlasCollector -Name 'test' -DisplayName 'Test objects' -Collector {
                throw 'Bearer unsafe-token'
            }

            $collector.Status | Should -Be 'partial'
            $collector.Warnings.Count | Should -Be 1
            $collector.Warnings[0] | Should -Not -Match 'unsafe-token'
            $collector.Metrics.failed | Should -Be $true
        }

        It 'allows only recognised Microsoft Graph request hosts and API paths' {
            (Test-AtlasGraphUri -Uri '/v1.0/users') | Should -Be $true
            (Test-AtlasGraphUri -Uri 'https://graph.microsoft.com/v1.0/users?$top=1') | Should -Be $true
            (Test-AtlasGraphUri -Uri 'https://graph.microsoft.us/v1.0/groups') | Should -Be $true
            (Test-AtlasGraphUri -Uri 'https://example.com/v1.0/users') | Should -Be $false
            (Test-AtlasGraphUri -Uri 'http://graph.microsoft.com/v1.0/users') | Should -Be $false
            (Test-AtlasGraphUri -Uri '/me') | Should -Be $false
        }

        It 'rejects an unrecognised Graph request URI before making a request' {
            Mock Invoke-MgGraphRequest {
                throw 'Invoke-MgGraphRequest should not be called.'
            }

            $threw = $false
            try {
                Invoke-AtlasGraphRequest -Uri 'https://example.com/v1.0/users'
            }
            catch {
                $threw = $true
            }
            $threw | Should -Be $true
            Assert-MockCalled Invoke-MgGraphRequest -Times 0
        }

        It 'keeps an empty Graph value collection empty' {
            Mock Invoke-MgGraphRequest {
                [pscustomobject] @{
                    value = @()
                    '@odata.nextLink' = $null
                }
            }

            $response = Invoke-AtlasGraphRequest -Uri '/v1.0/groups'

            $response.Items.Count | Should -Be 0
            $response.Metrics.itemCount | Should -Be 0
        }

        It 'collects a directory role assignment without appScopeId' {
            Mock Invoke-AtlasGraphRequest {
                param($Uri)

                if ($Uri -like '*roleDefinitions*') {
                    return [pscustomobject] @{
                        Items = @(
                            [pscustomobject] @{
                                id = 'role-1'
                                displayName = 'Test role'
                                description = 'Test role definition'
                                isBuiltIn = $true
                                isEnabled = $true
                            }
                        )
                        Metrics = @{ requestCount = 1; retryCount = 0 }
                    }
                }

                if ($Uri -like '*roleEligibilityScheduleInstances*') {
                    return [pscustomobject] @{
                        Items = @()
                        Metrics = @{ requestCount = 1; retryCount = 0 }
                    }
                }

                return [pscustomobject] @{
                    Items = @(
                        [pscustomobject] @{
                            id = 'assignment-1'
                            principalId = 'user-1'
                            roleDefinitionId = 'role-1'
                            directoryScopeId = '/'
                        }
                    )
                    Metrics = @{ requestCount = 1; retryCount = 0 }
                }
            }

            $knownNode = New-AtlasNode -TenantId 'tenant-1' -Id 'user-1' -Kind 'user' -DisplayName 'Test user'
            $result = Get-AtlasDirectoryRole -TenantId 'tenant-1' -KnownNode @($knownNode)

            $result.Edges.Count | Should -Be 1
            $result.Evidence.Count | Should -Be 1
            $result.Edges[0].State.appScopeId | Should -Be $null
        }

        It 'collects application app role assignments' {
            Mock Invoke-AtlasGraphRequest {
                param($Uri)

                if ($Uri -like '*appRoleAssignedTo*') {
                    return [pscustomobject] @{
                        Items = @(
                            [pscustomobject] @{
                                id = 'assignment-1'
                                principalId = 'user-1'
                                principalDisplayName = 'Test user'
                                principalType = 'User'
                                resourceId = 'sp-1'
                                resourceDisplayName = 'Test app'
                                appRoleId = 'role-1'
                                createdDateTime = '2026-07-27T10:00:00Z'
                            }
                        )
                        Metrics = @{ requestCount = 1; retryCount = 0 }
                    }
                }

                if ($Uri -like '*applications*' -or $Uri -like '*owners*') {
                    return [pscustomobject] @{
                        Items = @()
                        Metrics = @{ requestCount = 1; retryCount = 0 }
                    }
                }

                return [pscustomobject] @{
                    Items = @(
                        [pscustomobject] @{
                            id = 'sp-1'
                            appId = 'app-1'
                            displayName = 'Test app'
                            servicePrincipalType = 'Application'
                            accountEnabled = $true
                            appOwnerOrganizationId = 'tenant-1'
                            appRoles = @(
                                [pscustomobject] @{
                                    id = 'role-1'
                                    displayName = 'Read data'
                                    value = 'Data.Read'
                                }
                            )
                        }
                    )
                    Metrics = @{ requestCount = 1; retryCount = 0 }
                }
            }

            $knownNode = New-AtlasNode -TenantId 'tenant-1' -Id 'user-1' -Kind 'user' -DisplayName 'Test user'
            $result = Get-AtlasApplication -TenantId 'tenant-1' -KnownNode @($knownNode)

            $result.Nodes.Count | Should -Be 1
            $result.Edges.Count | Should -Be 1
            $result.Edges[0].Relationship | Should -Be 'assignedAppRole'
            $result.Edges[0].State.appRoleDisplayName | Should -Be 'Read data'
        }

        It 'collects a single application credential and API permission without scalar count errors' {
            Mock Invoke-AtlasGraphRequest {
                param($Uri)

                if ($Uri -like '*owners*') {
                    return [pscustomobject] @{
                        Items = @()
                        Metrics = @{ requestCount = 1; retryCount = 0 }
                    }
                }

                if ($Uri -like '*applications*') {
                    return [pscustomobject] @{
                        Items = @(
                            [pscustomobject] @{
                                id = 'application-1'
                                appId = 'client-1'
                                displayName = 'Single credential app'
                                signInAudience = 'AzureADMyOrg'
                                createdDateTime = '2026-07-27T10:00:00Z'
                                passwordCredentials = [pscustomobject] @{
                                    keyId = 'credential-1'
                                    displayName = 'Client secret'
                                    startDateTime = '2026-07-27T10:00:00Z'
                                    endDateTime = '2027-07-27T10:00:00Z'
                                }
                                keyCredentials = $null
                                requiredResourceAccess = [pscustomobject] @{
                                    resourceAppId = 'resource-1'
                                    resourceAccess = @(
                                        [pscustomobject] @{
                                            id = 'permission-1'
                                            type = 'Role'
                                        }
                                    )
                                }
                            }
                        )
                        Metrics = @{ requestCount = 1; retryCount = 0 }
                    }
                }

                return [pscustomobject] @{
                    Items = @()
                    Metrics = @{ requestCount = 1; retryCount = 0 }
                }
            }

            $knownNode = New-AtlasNode -TenantId 'tenant-1' -Id 'user-1' -Kind 'user' -DisplayName 'Test user'
            $result = Get-AtlasApplication -TenantId 'tenant-1' -KnownNode @($knownNode)
            $application = $result.Nodes | Where-Object Kind -eq 'application'

            @($application).Count | Should -Be 1
            $application.Properties.passwordCredentialCount | Should -Be 1
            $application.Properties.keyCredentialCount | Should -Be 0
            $application.Properties.requiredResourceAccessCount | Should -Be 1
            @($result.Nodes | Where-Object Kind -eq 'applicationCredential').Count | Should -Be 1
            @($result.Nodes | Where-Object Kind -eq 'apiPermission').Count | Should -Be 1
            @($result.Edges | Where-Object Relationship -eq 'hasCredential').Count | Should -Be 1
            @($result.Edges | Where-Object Relationship -eq 'requiresApiPermission').Count | Should -Be 1
        }

        It 'collects Conditional Access policy assignment relationships' {
            Mock Invoke-AtlasGraphRequest {
                [pscustomobject] @{
                    Items = @(
                        [pscustomobject] @{
                            id = 'policy-1'
                            displayName = 'Require MFA'
                            state = 'enabled'
                            createdDateTime = '2026-07-27T10:00:00Z'
                            modifiedDateTime = '2026-07-27T10:00:00Z'
                            conditions = [pscustomobject] @{
                                users = [pscustomobject] @{
                                    includeUsers = @('user-1')
                                    excludeUsers = @()
                                    includeGroups = @()
                                    excludeGroups = @('group-1')
                                }
                                applications = [pscustomobject] @{
                                    includeApplications = @('app-1')
                                    excludeApplications = @()
                                }
                            }
                            grantControls = [pscustomobject] @{
                                operator = 'OR'
                                builtInControls = @('mfa')
                            }
                            sessionControls = $null
                        }
                    )
                    Metrics = @{ requestCount = 1; retryCount = 0 }
                }
            }

            $knownNode = @(
                (New-AtlasNode -TenantId 'tenant-1' -Id 'user-1' -Kind 'user' -DisplayName 'Test user')
                (New-AtlasNode -TenantId 'tenant-1' -Id 'group-1' -Kind 'group' -DisplayName 'Test group')
                (New-AtlasNode -TenantId 'tenant-1' -Id 'sp-1' -Kind 'servicePrincipal' -DisplayName 'Test app' -Properties @{ appId = 'app-1' })
            )
            $result = Get-AtlasConditionalAccessPolicy -TenantId 'tenant-1' -KnownNode $knownNode

            $result.Nodes.Count | Should -Be 1
            $result.Edges.Count | Should -Be 3
            @($result.Edges | Where-Object Relationship -eq 'conditionalAccessIncludes').Count | Should -Be 2
            @($result.Edges | Where-Object Relationship -eq 'conditionalAccessExcludes').Count | Should -Be 1
        }

        It 'collects devices and user authentication methods' {
            Mock Invoke-AtlasGraphRequest {
                param($Uri)

                if ($Uri -like '*registeredOwners*') {
                    return [pscustomobject] @{
                        Items = @(
                            [pscustomobject] @{
                                id = 'user-1'
                                displayName = 'Test user'
                                '@odata.type' = '#microsoft.graph.user'
                            }
                        )
                        Metrics = @{ requestCount = 1; retryCount = 0 }
                    }
                }

                if ($Uri -like '*authentication/methods*') {
                    return [pscustomobject] @{
                        Items = @(
                            [pscustomobject] @{
                                id = 'method-1'
                                '@odata.type' = '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod'
                            }
                        )
                        Metrics = @{ requestCount = 1; retryCount = 0 }
                    }
                }

                return [pscustomobject] @{
                    Items = @(
                        [pscustomobject] @{
                            id = 'device-1'
                            displayName = 'Test device'
                            operatingSystem = 'Windows'
                            isCompliant = $true
                        }
                    )
                    Metrics = @{ requestCount = 1; retryCount = 0 }
                }
            }

            $knownNode = New-AtlasNode -TenantId 'tenant-1' -Id 'user-1' -Kind 'user' -DisplayName 'Test user'
            $result = Get-AtlasDeviceAndAuthentication -TenantId 'tenant-1' -KnownNode @($knownNode)

            @($result.Nodes | Where-Object Kind -eq 'device').Count | Should -Be 1
            @($result.Nodes | Where-Object Kind -eq 'authenticationMethod').Count | Should -Be 1
            @($result.Edges | Where-Object Relationship -eq 'registeredDevice').Count | Should -Be 1
            @($result.Edges | Where-Object Relationship -eq 'hasAuthenticationMethod').Count | Should -Be 1
        }

        It 'collects Conditional Access named location and authentication strength references' {
            Mock Invoke-AtlasGraphRequest {
                param($Uri)

                if ($Uri -like '*namedLocations*') {
                    return [pscustomobject] @{
                        Items = @(
                            [pscustomobject] @{
                                id = 'location-1'
                                displayName = 'Trusted office'
                                '@odata.type' = '#microsoft.graph.ipNamedLocation'
                                isTrusted = $true
                            }
                        )
                        Metrics = @{ requestCount = 1; retryCount = 0 }
                    }
                }

                if ($Uri -like '*authenticationStrengthPolicies*') {
                    return [pscustomobject] @{
                        Items = @(
                            [pscustomobject] @{
                                id = 'strength-1'
                                displayName = 'Phishing resistant'
                                policyType = 'builtIn'
                            }
                        )
                        Metrics = @{ requestCount = 1; retryCount = 0 }
                    }
                }

                return [pscustomobject] @{
                    Items = @(
                        [pscustomobject] @{
                            id = 'policy-1'
                            conditions = [pscustomobject] @{
                                locations = [pscustomobject] @{
                                    includeLocations = @('location-1')
                                    excludeLocations = @()
                                }
                            }
                            grantControls = [pscustomobject] @{
                                authenticationStrength = [pscustomobject] @{
                                    id = 'strength-1'
                                }
                            }
                        }
                        [pscustomobject] @{
                            id = 'policy-2'
                            conditions = $null
                            grantControls = [pscustomobject] @{
                                authenticationStrength = $null
                            }
                        }
                    )
                    Metrics = @{ requestCount = 1; retryCount = 0 }
                }
            }

            $knownNode = @(
                (New-AtlasNode -TenantId 'tenant-1' -Id 'policy-1' -Kind 'conditionalAccessPolicy' -DisplayName 'Test policy')
                (New-AtlasNode -TenantId 'tenant-1' -Id 'policy-2' -Kind 'conditionalAccessPolicy' -DisplayName 'Policy without references')
            )
            $result = Get-AtlasConditionalAccessReference -TenantId 'tenant-1' -KnownNode $knownNode

            @($result.Nodes | Where-Object Kind -eq 'namedLocation').Count | Should -Be 1
            @($result.Nodes | Where-Object Kind -eq 'authenticationStrength').Count | Should -Be 1
            @($result.Edges | Where-Object Relationship -eq 'conditionalAccessIncludesLocation').Count | Should -Be 1
            @($result.Edges | Where-Object Relationship -eq 'requiresAuthenticationStrength').Count | Should -Be 1
        }

        It 'accepts an empty known-node set after Conditional Access collection is denied' {
            Mock Invoke-AtlasGraphRequest {
                [pscustomobject] @{
                    Items = @()
                    Metrics = @{ requestCount = 1; retryCount = 0 }
                }
            }

            $result = Get-AtlasConditionalAccessReference -TenantId 'tenant-1' -KnownNode @()

            $result.Status | Should -Be 'complete'
            $result.Nodes.Count | Should -Be 0
            $result.Edges.Count | Should -Be 0
            $result.Evidence.Count | Should -Be 0
            $result.Metrics.requestCount | Should -Be 3
        }
    }
}
