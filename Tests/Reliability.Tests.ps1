BeforeAll {
    $script:module = Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'IdentityAtlas.psd1') -Force -PassThru
}

Describe 'Collection workflow and report trust' {
    It 'refuses to stop a process not launched by this module session' {
        { Stop-IdentityAtlasReport -ProcessId $PID -Confirm:$false } | Should -Throw '*not registered*'
    }

    It 'reports a missing Graph context without collecting' {
        Mock Get-MgContext { $null } -ModuleName IdentityAtlas
        (Test-IdentityAtlasConnection).Connected | Should -BeFalse
    }

    It 'round trips typed checkpoint data and rejects a changed context' {
        & $script:module {
            param($Root)
            $identity = @{ tenant = 'test-tenant'; account = 'test-account'; scopes = @('User.Read.All') }
            try {
                Initialize-AtlasCheckpoint -Path (Join-Path $Root 'resume.checkpoint') -Identity $identity
                $result = [AtlasCollectionResult]::new()
                $result.Nodes.Add((New-AtlasNode -TenantId 'test-tenant' -Id 'u' -Kind user -DisplayName 'Test user'))
                Save-AtlasCheckpointResult -Name users -Result $result
                Initialize-AtlasCheckpoint -Path (Join-Path $Root 'resume.checkpoint') -Identity $identity -Resume
                $restored = Get-AtlasCheckpointResult -Name users
                $restored.Nodes[0].Key | Should -Be $result.Nodes[0].Key
                $restored.Nodes[0].CollectedAtUtc | Should -Be $result.Nodes[0].CollectedAtUtc
                $restored.Metrics.checkpointReused | Should -BeTrue
                $identity.tenant = 'different-tenant'
                { Initialize-AtlasCheckpoint -Path (Join-Path $Root 'resume.checkpoint') -Identity $identity -Resume } | Should -Throw '*differ*'
            } finally { $script:AtlasCheckpoint = $null }
        } $TestDrive
    }

    It 'refreshes failed collectors and downstream stages on resume' {
        & $script:module {
            param($Root)
            $identity = @{ tenant = 'test-tenant' }
            try {
                Initialize-AtlasCheckpoint -Path (Join-Path $Root 'partial.checkpoint') -Identity $identity
                $partial = [AtlasCollectionResult]::new(); $partial.Status = 'partial'
                Save-AtlasCheckpointResult -Name users -Result $partial
                Save-AtlasCheckpointResult -Name groups -Result ([AtlasCollectionResult]::new())
                Initialize-AtlasCheckpoint -Path (Join-Path $Root 'partial.checkpoint') -Identity $identity -Resume
                Get-AtlasCheckpointResult -Name users | Should -BeNullOrEmpty
                Get-AtlasCheckpointResult -Name groups | Should -BeNullOrEmpty
            } finally { $script:AtlasCheckpoint = $null }
        } $TestDrive
    }

    It 'rejects expired checkpoints and reuses a complete empty collector' {
        & $script:module {
            param($Root)
            $path = Join-Path $Root 'expired.checkpoint'
            $identity = @{ tenant = 'test-tenant' }
            try {
                Initialize-AtlasCheckpoint -Path $path -Identity $identity
                Save-AtlasCheckpointResult -Name users -Result ([AtlasCollectionResult]::new())
                Initialize-AtlasCheckpoint -Path $path -Identity $identity -Resume
                (Get-AtlasCheckpointResult -Name users).Nodes.Count | Should -Be 0
                $markerPath = Join-Path $path 'checkpoint.json'
                $marker = Get-Content -LiteralPath $markerPath -Raw | ConvertFrom-Json
                $marker.createdAtUtc = [datetime]::UtcNow.AddHours(-25).ToString('o')
                Write-AtlasTextFile -Path $markerPath -Content ($marker | ConvertTo-Json)
                { Initialize-AtlasCheckpoint -Path $path -Identity $identity -Resume } | Should -Throw '*older than 24 hours*'
            } finally { $script:AtlasCheckpoint = $null }
        } $TestDrive
    }

    It 'does not report missing data as removals when coverage is partial' {
        & $script:module {
            param($Root)
            $collection = [AtlasCollectionResult]::new()
            $collection.Nodes.Add((New-AtlasNode -TenantId 'test-tenant' -Id 'u' -Kind user -DisplayName 'Test user'))
            $before = New-AtlasReport -TenantId 'test-tenant' -TenantDisplayName 'Test' -Collection $collection -Collectors @(@{ name = 'users'; status = 'complete' }) -DataOrigin SampleFixture
            $later = [AtlasCollectionResult]::new(); $later.Status = 'partial'
            $after = New-AtlasReport -TenantId 'test-tenant' -TenantDisplayName 'Test' -Collection $later -Collectors @(@{ name = 'users'; status = 'partial' }) -DataOrigin SampleFixture
            Write-AtlasTextFile -Path (Join-Path $Root 'before.json') -Content ($before | ConvertTo-Json -Depth 30)
            Write-AtlasTextFile -Path (Join-Path $Root 'after.json') -Content ($after | ConvertTo-Json -Depth 30)
            $comparison = Compare-IdentityAtlas -ReferenceReportPath (Join-Path $Root 'before.json') -DifferenceReportPath (Join-Path $Root 'after.json')
            $comparison.summary.removedNodes | Should -Be 0
            $comparison.summary.unobservedNodes | Should -Be 1
            $after.manifest.schemaVersion = 'incompatible-schema'
            Write-AtlasTextFile -Path (Join-Path $Root 'after.json') -Content ($after | ConvertTo-Json -Depth 30)
            { Compare-IdentityAtlas -ReferenceReportPath (Join-Path $Root 'before.json') -DifferenceReportPath (Join-Path $Root 'after.json') } | Should -Throw '*schema*'
            $after.manifest.schemaVersion = $before.manifest.schemaVersion
            $after.manifest.tenant.id = 'different-tenant'
            Write-AtlasTextFile -Path (Join-Path $Root 'after.json') -Content ($after | ConvertTo-Json -Depth 30)
            { Compare-IdentityAtlas -ReferenceReportPath (Join-Path $Root 'before.json') -DifferenceReportPath (Join-Path $Root 'after.json') } | Should -Throw '*same tenant*'
        } $TestDrive
    }

    It 'collects all-user and individual delegated consent without requesting write operations' {
        InModuleScope IdentityAtlas {
            Mock Invoke-AtlasGraphRequest {
                [pscustomobject]@{ Items = @(
                    @{ id = 'grant1'; clientId = 'client'; resourceId = 'api'; principalId = $null; consentType = 'AllPrincipals'; scope = 'User.Read' },
                    @{ id = 'grant2'; clientId = 'client'; resourceId = 'api'; principalId = 'user'; consentType = 'Principal'; scope = 'User.Read' }
                ); Metrics = @{ requestCount = 1; retryCount = 0 } }
            } -ParameterFilter { $Uri -eq '/v1.0/oauth2PermissionGrants' }
            $known = @(
                New-AtlasNode -TenantId 'test-tenant' -Id client -Kind servicePrincipal -DisplayName 'Client'
                New-AtlasNode -TenantId 'test-tenant' -Id api -Kind servicePrincipal -DisplayName 'API'
                New-AtlasNode -TenantId 'test-tenant' -Id user -Kind user -DisplayName 'User'
            )
            $result = Get-AtlasConsent -TenantId 'test-tenant' -KnownNode $known
            $result.Status | Should -Be complete
            $result.Nodes.Count | Should -Be 2
            @($result.Edges | Where-Object Relationship -eq subjectOfDelegatedConsent).Count | Should -Be 1
            @($result.Edges | Where-Object Relationship -eq hasDelegatedConsent).Count | Should -Be 2
            Should -Invoke Invoke-AtlasGraphRequest -Times 1
        }
    }
}
