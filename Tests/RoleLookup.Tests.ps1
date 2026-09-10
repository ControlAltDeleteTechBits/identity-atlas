BeforeAll {
    Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'IdentityAtlas.psd1') -Force
}

Describe 'Referenced role definition fallback' {
    It 'preserves active and eligible assignments when direct lookup is <Mode>' -TestCases @(
        @{ Mode = 'successful' }, @{ Mode = 'denied' }, @{ Mode = 'mismatched' }, @{ Mode = 'empty' }
    ) {
        param($Mode)
        InModuleScope IdentityAtlas -Parameters @{ Mode = $Mode } {
            param($Mode)
            Mock Invoke-AtlasGraphRequest {
                param($Uri)
                $items = @()
                if ($Uri -like '*roleAssignmentScheduleInstances*' -or $Uri -like '*roleManagementPolicyAssignments*') { $items = @() }
                elseif ($Uri -like '*roleDefinitions[?]*') { $items = @() }
                elseif ($Uri -like '*roleDefinitions/*') {
                    if ($Mode -eq 'denied') { throw 'HTTP 403 Forbidden' }
                    if ($Mode -ne 'empty') {
                        $items = @(@{ id = if ($Mode -eq 'mismatched') { 'wrong-role' } else { 'missing-role' }; displayName = 'Recovered role'; description = 'Test'; isBuiltIn = $true; isEnabled = $true })
                    }
                }
                else {
                    $items = @(@{ id = $Uri; principalId = 'user'; roleDefinitionId = 'missing-role'; directoryScopeId = '/' })
                }
                [pscustomobject]@{ Items = $items; Metrics = @{ requestCount = 1; retryCount = 0 } }
            }
            $user = New-AtlasNode -TenantId 'test-tenant' -Id user -Kind user -DisplayName 'Test user'
            $result = Get-AtlasDirectoryRole -TenantId 'test-tenant' -KnownNode @($user)
            $result.Edges.Count | Should -Be 2
            $result.Evidence.Count | Should -Be 2
            $result.Nodes.Count | Should -Be 1
            $result.Nodes[0].Id | Should -Be 'missing-role'
            $result.Metrics.directRoleLookupCount | Should -Be 1
            $result.Metrics.requestCount | Should -Be 6
            Should -Invoke Invoke-AtlasGraphRequest -Times 1 -Exactly -ParameterFilter { $Uri -eq '/v1.0/roleManagement/directory/roleAssignments' }
            Should -Invoke Invoke-AtlasGraphRequest -Times 1 -Exactly -ParameterFilter { $Uri -eq '/v1.0/roleManagement/directory/roleDefinitions/missing-role' }
            if ($Mode -eq 'successful') {
                $result.Status | Should -Be complete
                $result.Nodes[0].DisplayName | Should -Be 'Recovered role'
                $result.Metrics.roleDefinitionCount | Should -Be 1
                @($result.Evidence | Where-Object Completeness -ne complete).Count | Should -Be 0
            } else {
                $result.Status | Should -Be partial
                $result.Nodes[0].Status | Should -Be unresolved
                $result.Metrics.unresolvedRoleDefinitionCount | Should -Be 1
                @($result.Evidence | Where-Object Completeness -eq partial).Count | Should -Be 2
            }
        }
    }
}
