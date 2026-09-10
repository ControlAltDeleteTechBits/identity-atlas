BeforeAll {
    Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) 'IdentityAtlas.psd1') -Force
}

Describe 'PIM protection evidence collection' {
    It 'joins schedule origins without replacing assignment evidence and retains policy rules' {
        InModuleScope IdentityAtlas {
            Mock Invoke-AtlasGraphRequest {
                param($Uri)
                $items = if ($Uri -like '*roleAssignmentScheduleInstances*') {
                    @(@{ id = 'instance'; roleAssignmentOriginId = 'assignment'; assignmentType = 'Activated'; endDateTime = '2026-09-11T12:00:00Z' })
                } else {
                    @(@{ id = 'policy-assignment'; roleDefinitionId = 'role'; policyId = 'policy'; scopeId = '/'; scopeType = 'DirectoryRole'; policy = @{ rules = @(@{ id = 'Approval_EndUser_Assignment'; setting = @{ isApprovalRequired = $true } }) } })
                }
                [pscustomobject]@{ Items = $items; Metrics = @{ requestCount = 1; retryCount = 0 } }
            }
            $result = [AtlasCollectionResult]::new()
            $role = New-AtlasNode -TenantId test -Id role -Kind roleDefinition -DisplayName Role
            $result.Nodes.Add($role)
            $edge = New-AtlasEdge -TenantId test -From user -To $role.Key -Relationship assignedRole -State @{ assignmentId = 'assignment' } -EvidenceIds @('original')
            $result.Edges.Add($edge)
            $metrics = Add-AtlasRoleProtectionEvidence -TenantId test -Result $result
            $metrics.requestCount | Should -Be 2
            $result.Edges.Count | Should -Be 1
            $edge.State.scheduleInstances[0].assignmentType | Should -Be Activated
            $edge.EvidenceIds | Should -Contain original
            $role.Properties.pimPolicies[0].rules[0].setting.isApprovalRequired | Should -BeTrue
            $result.Evidence.Count | Should -Be 2
        }
    }
    It 'records denied collection as partial without inventing a protection verdict' {
        InModuleScope IdentityAtlas {
            Mock Invoke-AtlasGraphRequest { throw 'HTTP 403' }
            $result = [AtlasCollectionResult]::new()
            Add-AtlasRoleProtectionEvidence -TenantId test -Result $result | Out-Null
            $result.Status | Should -Be partial
            $result.Warnings.Count | Should -Be 2
            $result.Evidence.Count | Should -Be 0
        }
    }
    It 'propagates cancellation' {
        InModuleScope IdentityAtlas {
            Mock Invoke-AtlasGraphRequest { throw [System.OperationCanceledException]::new() }
            { Add-AtlasRoleProtectionEvidence -TenantId test -Result ([AtlasCollectionResult]::new()) } | Should -Throw
        }
    }
}
