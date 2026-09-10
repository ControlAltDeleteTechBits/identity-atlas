BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../IdentityAtlas.psd1') -Force
}
Describe 'Admin workspace collection metadata' {
    It 'retains only allowed federated credential metadata using bounded read batches' {
        InModuleScope IdentityAtlas {
            Mock Invoke-AtlasGraphBatchGet {
                [pscustomobject] @{
                    Metrics = @{ requestCount = 1; retryCount = 0; logicalRequestCount = 1 }
                    Responses = @([pscustomobject] @{
                        Id = 'federation-0'; StatusCode = 200
                        Items = @(@{ id = 'trust'; name = 'build'; issuer = 'https://issuer.example'; subject = 'repo:test'; audiences = @('api://exchange'); secretText = 'do-not-retain'; key = 'do-not-retain' })
                    })
                }
            }
            $result = [AtlasCollectionResult]::new()
            $node = New-AtlasNode -TenantId test -Id app -Kind application -DisplayName App
            $result.Nodes.Add($node)
            $metrics = Add-AtlasApplicationAdminDetail -Result $result -BatchSize 3
            $metrics.requestCount | Should -Be 1
            $node.Properties.federatedIdentityCredentials[0].subject | Should -Be 'repo:test'
            $node.Properties.federatedIdentityCredentials[0].ContainsKey('secretText') | Should -BeFalse
            $node.Properties.federatedIdentityCredentials[0].ContainsKey('key') | Should -BeFalse
            Should -Invoke Invoke-AtlasGraphBatchGet -Times 1 -ParameterFilter { $BatchSize -eq 3 -and $Request[0].Uri -like '/v1.0/applications/app/federatedIdentityCredentials*' }
        }
    }
    It 'records denied federation evidence as unknown rather than an empty successful collection' {
        InModuleScope IdentityAtlas {
            Mock Invoke-AtlasGraphBatchGet { throw 'HTTP 403' }
            $result = [AtlasCollectionResult]::new()
            $node = New-AtlasNode -TenantId test -Id app -Kind application -DisplayName App
            $result.Nodes.Add($node)
            Add-AtlasApplicationAdminDetail -Result $result | Out-Null
            $result.Status | Should -Be partial
            $node.Properties.federationCollectionStatus | Should -Be partial
            $node.Properties.ContainsKey('federatedIdentityCredentials') | Should -BeFalse
        }
    }
    It 'does not query federation metadata when no registrations were collected' {
        InModuleScope IdentityAtlas {
            Mock Invoke-AtlasGraphBatchGet { throw 'Should not run' }
            Add-AtlasApplicationAdminDetail -Result ([AtlasCollectionResult]::new()) | Out-Null
            Should -Invoke Invoke-AtlasGraphBatchGet -Times 0
        }
    }
    It 'resolves an omitted manager with an explicit 404 while retaining the response status' {
        InModuleScope IdentityAtlas {
            Mock Invoke-AtlasGraphRequest {
                [pscustomobject] @{ Items = @(@{ id = 'one'; displayName = 'One'; userPrincipalName = 'one'; userType = 'Member'; accountEnabled = $true }); Metrics = @{ requestCount = 1; retryCount = 0 } }
            }
            Mock Invoke-AtlasGraphBatchGet {
                [pscustomobject] @{ Metrics = @{ requestCount = 1; retryCount = 0 }; Responses = @([pscustomobject] @{ Id = 'manager-0'; StatusCode = 404; Items = @() }) }
            }
            $result = Get-AtlasUser -TenantId test
            $result.Nodes[0].Properties.managerCollectionStatus | Should -Be collected
            $result.Nodes[0].Properties.managerRequestStatus | Should -Be 404
            $result.Metrics.requestCount | Should -Be 2
        }
    }
    It 'limits service principal key collection to metadata and retains role actions' {
        $project = Split-Path $PSScriptRoot -Parent
        $app = Get-Content (Join-Path $project 'Private/23-GetAtlasApplications.ps1') -Raw
        $role = Get-Content (Join-Path $project 'Private/22-GetAtlasDirectoryRoles.ps1') -Raw
        $app | Should -Match 'preferredSingleSignOnMode,preferredTokenSigningKeyThumbprint,keyCredentials'
        $app | Should -Match 'signingCertificates ='
        $app | Should -Not -Match '-Name ''(?:key|secretText)'''
        $role | Should -Match 'rolePermissions ='
    }
    It 'retains manager collection uncertainty and does not invent an absent manager' {
        InModuleScope IdentityAtlas {
            Mock Invoke-AtlasGraphBatchGet { throw 'HTTP 403' }
            Mock Invoke-AtlasGraphRequest {
                [pscustomobject] @{
                    Items = @(
                        @{ id = 'one'; displayName = 'One'; userPrincipalName = 'one'; userType = 'Member'; accountEnabled = $true; manager = $null },
                        @{ id = 'two'; displayName = 'Two'; userPrincipalName = 'two'; userType = 'Member'; accountEnabled = $true }
                    )
                    Metrics = @{ requestCount = 1; retryCount = 0 }
                }
            }
            $result = Get-AtlasUser -TenantId test
            $result.Nodes[0].Properties.managerCollectionStatus | Should -Be collected
            $result.Nodes[1].Properties.managerCollectionStatus | Should -Be unknown
            Should -Invoke Invoke-AtlasGraphRequest -Times 1 -ParameterFilter { $Uri -match '\$expand=manager' }
        }
    }
}
