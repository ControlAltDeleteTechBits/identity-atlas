$projectRoot = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $projectRoot 'IdentityAtlas.psd1') -Force

Describe 'Identity Atlas relationship and governance collectors' {
    InModuleScope IdentityAtlas {
        BeforeAll {
            function Get-TestGraphResponse {
                param([object[]] $Items = @())
                return [pscustomobject] @{
                    Items = @($Items)
                    Metrics = @{ requestCount = 1; retryCount = 0 }
                }
            }
        }

        It 'keeps governance permissions opt-in and includes the complete approved set' {
            $core = Get-AtlasRecommendedScope -CollectionProfile Core
            $governance = Get-AtlasRecommendedScope -CollectionProfile Governance
            $approvedGovernanceScope = @(
                'AdministrativeUnit.Read.All'
                'PrivilegedAssignmentSchedule.Read.AzureADGroup'
                'PrivilegedEligibilitySchedule.Read.AzureADGroup'
                'EntitlementManagement.Read.All'
                'AccessReview.Read.All'
            )

            foreach ($scope in $approvedGovernanceScope) {
                ($core -contains $scope) | Should -Be $false
                ($governance -contains $scope) | Should -Be $true
            }
        }

        It 'wires every extended and Governance collector into the public invocation command' {
            $script:extendedCollectorCalls = @{}
            Mock Get-MgContext {
                [pscustomobject] @{
                    TenantId = 'tenant-one'
                    Scopes = @(Get-AtlasRecommendedScope -CollectionProfile Governance)
                }
            }
            Mock Get-AtlasUser { [AtlasCollectionResult]::new() }
            Mock Get-AtlasGroup { [AtlasCollectionResult]::new() }
            Mock Get-AtlasDeviceAndAuthentication { [AtlasCollectionResult]::new() }
            Mock Get-AtlasDirectoryRole { [AtlasCollectionResult]::new() }
            Mock Get-AtlasApplication { [AtlasCollectionResult]::new() }
            Mock Get-AtlasApplicationManagementPolicy { $script:extendedCollectorCalls.applicationManagementPolicies = 1; [AtlasCollectionResult]::new() }
            Mock Get-AtlasCrossTenantAccess { $script:extendedCollectorCalls.crossTenantAccess = 1; [AtlasCollectionResult]::new() }
            Mock Get-AtlasConditionalAccessPolicy { [AtlasCollectionResult]::new() }
            Mock Get-AtlasConditionalAccessReference { [AtlasCollectionResult]::new() }
            Mock Get-AtlasAdministrativeUnit { $script:extendedCollectorCalls.administrativeUnits = 1; [AtlasCollectionResult]::new() }
            Mock Get-AtlasPrivilegedGroupAssignment { $script:extendedCollectorCalls.pimGroups = 1; [AtlasCollectionResult]::new() }
            Mock Get-AtlasEntitlementManagement { $script:extendedCollectorCalls.entitlementManagement = 1; [AtlasCollectionResult]::new() }
            Mock Get-AtlasAccessReview { $script:extendedCollectorCalls.accessReviews = 1; [AtlasCollectionResult]::new() }
            Mock Write-AtlasReport { [System.IO.FileInfo]::new('C:\IdentityAtlasTest\index.html') }
            Mock Start-AtlasReportServer {
                [pscustomobject] @{ Url = 'http://127.0.0.1:8766/'; Port = 8766; ProcessId = 42 }
            }

            $invocation = Invoke-IdentityAtlas -CollectionProfile Governance -OutputPath 'C:\IdentityAtlasTest' -OpenReport

            $invocation.CollectionProfile | Should -Be 'Governance'
            $invocation.ReportUrl | Should -Be 'http://127.0.0.1:8766/'
            $invocation.ServerProcessId | Should -Be 42
            $script:extendedCollectorCalls.applicationManagementPolicies | Should -Be 1
            $script:extendedCollectorCalls.crossTenantAccess | Should -Be 1
            $script:extendedCollectorCalls.administrativeUnits | Should -Be 1
            $script:extendedCollectorCalls.pimGroups | Should -Be 1
            $script:extendedCollectorCalls.entitlementManagement | Should -Be 1
            $script:extendedCollectorCalls.accessReviews | Should -Be 1
        }

        It 'collects nested group membership with every intermediate group retained' {
            Mock Invoke-AtlasGraphRequest {
                param($Uri)
                if ($Uri -eq '/v1.0/groups?$select=id,displayName,description,groupTypes,mailEnabled,securityEnabled,isAssignableToRole,membershipRule') {
                    return Get-TestGraphResponse -Items @(
                        [pscustomobject] @{ id = 'group-parent'; displayName = 'Parent group'; description = $null; groupTypes = @(); mailEnabled = $false; securityEnabled = $true; isAssignableToRole = $false; membershipRule = $null }
                        [pscustomobject] @{ id = 'group-child'; displayName = 'Child group'; description = $null; groupTypes = @(); mailEnabled = $false; securityEnabled = $true; isAssignableToRole = $false; membershipRule = $null }
                    )
                }
                if ($Uri -like '*/group-parent/members*') {
                    return Get-TestGraphResponse -Items @([pscustomobject] @{ id = 'group-child'; displayName = 'Child group'; '@odata.type' = '#microsoft.graph.group' })
                }
                if ($Uri -like '*/group-child/members*') {
                    return Get-TestGraphResponse -Items @([pscustomobject] @{ id = 'user-one'; displayName = 'Test user'; '@odata.type' = '#microsoft.graph.user' })
                }
                return Get-TestGraphResponse
            }

            $result = Get-AtlasGroup -TenantId 'tenant-one'

            @($result.Edges | Where-Object { $_.From -like '*group-child' -and $_.To -like '*group-parent' -and $_.Relationship -eq 'memberOf' }).Count | Should -Be 1
            @($result.Edges | Where-Object { $_.From -like '*user-one' -and $_.To -like '*group-child' -and $_.Relationship -eq 'memberOf' }).Count | Should -Be 1
            $result.Metrics.nestedGroupMembershipCount | Should -Be 1
        }

        It 'collects default and partner-specific cross-tenant access settings' {
            Mock Invoke-AtlasGraphRequest {
                param($Uri)
                if ($Uri -like '*partners*') {
                    return Get-TestGraphResponse -Items @(
                        [pscustomobject] @{
                            tenantId = 'partner-tenant'
                            isServiceProvider = $false
                            b2bCollaborationInbound = @{ usersAndGroups = @{ accessType = 'allowed' } }
                            identitySynchronization = @{ displayName = 'Partner Organisation'; userSyncInbound = @{ isSyncAllowed = $true } }
                        }
                    )
                }
                return Get-TestGraphResponse -Items @(
                    [pscustomobject] @{
                        b2bCollaborationInbound = @{ usersAndGroups = @{ accessType = 'allowed' } }
                        b2bCollaborationOutbound = @{ usersAndGroups = @{ accessType = 'allowed' } }
                    }
                )
            }

            $result = Get-AtlasCrossTenantAccess -TenantId 'tenant-one'

            @($result.Nodes | Where-Object Kind -eq 'crossTenantAccessPolicy').Count | Should -Be 1
            @($result.Nodes | Where-Object Kind -eq 'externalTenant').Count | Should -Be 1
            @($result.Edges | Where-Object Relationship -eq 'hasCrossTenantPartner').Count | Should -Be 1
            $result.Edges[0].State.userSyncInboundAllowed | Should -Be $true
        }

        It 'connects explicit and default application management policies to applications' {
            Mock Invoke-AtlasGraphRequest {
                param($Uri)
                if ($Uri -eq '/v1.0/policies/defaultAppManagementPolicy') {
                    return Get-TestGraphResponse -Items @([pscustomobject] @{ displayName = 'Default app policy'; isEnabled = $true; applicationRestrictions = @{ passwordCredentials = @() }; servicePrincipalRestrictions = @{} })
                }
                if ($Uri -eq '/v1.0/policies/appManagementPolicies') {
                    return Get-TestGraphResponse -Items @([pscustomobject] @{ id = 'policy-one'; displayName = 'Strict app policy'; isEnabled = $true; restrictions = @{ passwordCredentials = @() } })
                }
                return Get-TestGraphResponse -Items @([pscustomobject] @{ id = 'app-one'; appId = 'client-one'; displayName = 'App one'; '@odata.type' = '#microsoft.graph.application' })
            }
            $appOne = New-AtlasNode -TenantId 'tenant-one' -Id 'app-one' -Kind 'application' -DisplayName 'App one'
            $appTwo = New-AtlasNode -TenantId 'tenant-one' -Id 'app-two' -Kind 'application' -DisplayName 'App two'

            $result = Get-AtlasApplicationManagementPolicy -TenantId 'tenant-one' -KnownNode @($appOne, $appTwo)

            @($result.Edges | Where-Object { $_.From -eq $appOne.Key -and $_.Relationship -eq 'governedByAppManagementPolicy' }).Count | Should -Be 1
            @($result.Edges | Where-Object { $_.From -eq $appTwo.Key -and $_.Relationship -eq 'governedByDefaultAppManagementPolicy' }).Count | Should -Be 1
        }

        It 'collects Administrative Unit membership and scoped role administration' {
            Mock Invoke-AtlasGraphRequest {
                param($Uri)
                if ($Uri -like '*/members*') {
                    return Get-TestGraphResponse -Items @([pscustomobject] @{ id = 'user-one'; displayName = 'Test user'; '@odata.type' = '#microsoft.graph.user' })
                }
                return Get-TestGraphResponse -Items @([pscustomobject] @{ id = 'unit-one'; displayName = 'UK Operations'; membershipType = 'assigned'; isMemberManagementRestricted = $true })
            }
            $user = New-AtlasNode -TenantId 'tenant-one' -Id 'user-one' -Kind 'user' -DisplayName 'Test user'
            $role = New-AtlasNode -TenantId 'tenant-one' -Id 'role-one' -Kind 'roleDefinition' -DisplayName 'User Administrator'
            $assignment = New-AtlasEdge -TenantId 'tenant-one' -From $user.Key -To $role.Key -Relationship 'assignedRole' -State @{ assignmentId = 'assignment-one'; activation = 'active'; directoryScopeId = '/administrativeUnits/unit-one' }

            $result = Get-AtlasAdministrativeUnit -TenantId 'tenant-one' -KnownNode @($user, $role) -KnownEdge @($assignment)

            @($result.Edges | Where-Object Relationship -eq 'memberOfAdministrativeUnit').Count | Should -Be 1
            @($result.Edges | Where-Object Relationship -eq 'administersAdministrativeUnit').Count | Should -Be 1
            @($result.Edges | Where-Object Relationship -eq 'scopedToAdministrativeUnit').Count | Should -Be 1
        }

        It 'collects active and eligible PIM for Groups assignments' {
            Mock Invoke-AtlasGraphRequest {
                param($Uri)
                if ($Uri -like '*eligibilityScheduleInstances*') {
                    return Get-TestGraphResponse -Items @([pscustomobject] @{ id = 'eligible-one'; groupId = 'group-one'; principalId = 'user-one'; accessId = 'owner'; memberType = 'Direct'; startDateTime = '2026-08-01T00:00:00Z' })
                }
                return Get-TestGraphResponse -Items @([pscustomobject] @{ id = 'active-one'; groupId = 'group-one'; principalId = 'user-one'; accessId = 'member'; memberType = 'Direct'; assignmentType = 'Activated'; startDateTime = '2026-08-01T00:00:00Z' })
            }
            $user = New-AtlasNode -TenantId 'tenant-one' -Id 'user-one' -Kind 'user' -DisplayName 'Test user'
            $group = New-AtlasNode -TenantId 'tenant-one' -Id 'group-one' -Kind 'group' -DisplayName 'Privileged group'

            $result = Get-AtlasPrivilegedGroupAssignment -TenantId 'tenant-one' -KnownNode @($user, $group)

            @($result.Edges | Where-Object Relationship -eq 'pimActiveMember').Count | Should -Be 1
            @($result.Edges | Where-Object Relationship -eq 'pimEligibleOwner').Count | Should -Be 1
            $result.Metrics.activeAssignmentCount | Should -Be 1
            $result.Metrics.eligibleAssignmentCount | Should -Be 1
        }

        It 'retains active PIM group assignments when the eligible request fails' {
            Mock Invoke-AtlasGraphRequest {
                param($Uri)
                if ($Uri -like '*eligibilityScheduleInstances*') {
                    throw 'Eligible schedules are unavailable'
                }
                return Get-TestGraphResponse -Items @([pscustomobject] @{ id = 'active-one'; groupId = 'group-one'; principalId = 'user-one'; accessId = 'member'; memberType = 'Direct'; assignmentType = 'Activated' })
            }
            $user = New-AtlasNode -TenantId 'tenant-one' -Id 'user-one' -Kind 'user' -DisplayName 'Test user'
            $group = New-AtlasNode -TenantId 'tenant-one' -Id 'group-one' -Kind 'group' -DisplayName 'Privileged group'

            $result = Get-AtlasPrivilegedGroupAssignment -TenantId 'tenant-one' -KnownNode @($user, $group)

            @($result.Edges | Where-Object Relationship -eq 'pimActiveMember').Count | Should -Be 1
            $result.Status | Should -Be 'partial'
            $result.Metrics.failedGroupCount | Should -Be 1
            $result.Metrics.failedRequestCount | Should -Be 1
        }

        It 'collects Entitlement Management catalogues packages policies resources and assignments' {
            Mock Invoke-AtlasGraphRequest {
                param($Uri)
                if ($Uri -like '*catalogs?*') {
                    return Get-TestGraphResponse -Items @([pscustomobject] @{ id = 'catalog-one'; displayName = 'General'; catalogType = 'serviceDefault'; state = 'published' })
                }
                if ($Uri -like '*accessPackages/package-one?*') {
                    return Get-TestGraphResponse -Items @([pscustomobject] @{
                        id = 'package-one'
                        resourceRoleScopes = @([pscustomobject] @{
                            id = 'scope-one'
                            role = [pscustomobject] @{ originId = 'member'; displayName = 'Member'; originSystem = 'AadGroup' }
                            scope = [pscustomobject] @{ originId = 'group-one'; displayName = 'Finance group'; originSystem = 'AadGroup' }
                        })
                    })
                }
                if ($Uri -like '*accessPackages?*') {
                    return Get-TestGraphResponse -Items @([pscustomobject] @{ id = 'package-one'; displayName = 'Finance access'; catalog = [pscustomobject] @{ id = 'catalog-one' } })
                }
                if ($Uri -like '*assignmentPolicies*') {
                    return Get-TestGraphResponse -Items @([pscustomobject] @{ id = 'assignment-policy-one'; displayName = 'Employee requests'; accessPackage = [pscustomobject] @{ id = 'package-one' }; allowedTargetScope = 'specificDirectoryUsers' })
                }
                return Get-TestGraphResponse -Items @([pscustomobject] @{ id = 'assignment-one'; target = [pscustomobject] @{ objectId = 'user-one'; displayName = 'Test user' }; accessPackage = [pscustomobject] @{ id = 'package-one' }; state = 'Delivered'; status = 'Delivered' })
            }
            $user = New-AtlasNode -TenantId 'tenant-one' -Id 'user-one' -Kind 'user' -DisplayName 'Test user'
            $group = New-AtlasNode -TenantId 'tenant-one' -Id 'group-one' -Kind 'group' -DisplayName 'Finance group'

            $result = Get-AtlasEntitlementManagement -TenantId 'tenant-one' -KnownNode @($user, $group)

            @($result.Nodes | Where-Object Kind -eq 'accessPackageCatalog').Count | Should -Be 1
            @($result.Nodes | Where-Object Kind -eq 'accessPackage').Count | Should -Be 1
            @($result.Edges | Where-Object Relationship -eq 'containsAccessPackage').Count | Should -Be 1
            @($result.Edges | Where-Object Relationship -eq 'governedByAccessPackagePolicy').Count | Should -Be 1
            @($result.Edges | Where-Object Relationship -eq 'grantsEntitlementResourceRole').Count | Should -Be 1
            @($result.Edges | Where-Object Relationship -eq 'assignedAccessPackage').Count | Should -Be 1
        }

        It 'collects Access Review definitions reviewers instances and decisions' {
            Mock Invoke-AtlasGraphRequest {
                param($Uri)
                if ($Uri -eq '/v1.0/identityGovernance/accessReviews/definitions') {
                    return Get-TestGraphResponse -Items @([pscustomobject] @{
                        id = 'review-one'
                        displayName = 'Quarterly finance review'
                        status = 'InProgress'
                        scope = [pscustomobject] @{ query = '/groups/20000000-0000-0000-0000-000000000003/transitiveMembers'; queryType = 'MicrosoftGraph' }
                        reviewers = @([pscustomobject] @{ query = '/users/10000000-0000-0000-0000-000000000004'; queryType = 'MicrosoftGraph' })
                        fallbackReviewers = @()
                        settings = @{ recurrence = @{ pattern = @{ type = 'absoluteMonthly' } } }
                    })
                }
                if ($Uri -like '*/instances/*/decisions') {
                    return Get-TestGraphResponse -Items @([pscustomobject] @{
                        id = 'decision-one'
                        principal = [pscustomobject] @{ id = '10000000-0000-0000-0000-000000000004'; displayName = 'Test user' }
                        resource = [pscustomobject] @{ id = '20000000-0000-0000-0000-000000000003'; displayName = 'Finance group'; type = 'Group' }
                        decision = 'Approve'
                        recommendation = 'Approve'
                        reviewedDateTime = '2026-08-02T12:00:00Z'
                    })
                }
                return Get-TestGraphResponse -Items @([pscustomobject] @{ id = 'instance-one'; status = 'InProgress'; startDateTime = '2026-08-01T00:00:00Z'; endDateTime = '2026-08-31T23:59:59Z' })
            }
            $user = New-AtlasNode -TenantId 'tenant-one' -Id '10000000-0000-0000-0000-000000000004' -Kind 'user' -DisplayName 'Test user'
            $group = New-AtlasNode -TenantId 'tenant-one' -Id '20000000-0000-0000-0000-000000000003' -Kind 'group' -DisplayName 'Finance group'

            $result = Get-AtlasAccessReview -TenantId 'tenant-one' -KnownNode @($user, $group)

            @($result.Nodes | Where-Object Kind -eq 'accessReviewDefinition').Count | Should -Be 1
            @($result.Nodes | Where-Object Kind -eq 'accessReviewInstance').Count | Should -Be 1
            @($result.Edges | Where-Object Relationship -eq 'coveredByAccessReview').Count | Should -Be 1
            @($result.Edges | Where-Object Relationship -eq 'reviewsAccess').Count | Should -Be 1
            @($result.Edges | Where-Object Relationship -eq 'hasAccessReviewInstance').Count | Should -Be 1
            @($result.Edges | Where-Object Relationship -eq 'reviewedInAccessReview').Count | Should -Be 1
            @($result.Edges | Where-Object Relationship -eq 'resourceReviewedInAccessReview').Count | Should -Be 1
        }
    }
}

Describe 'Identity Atlas governance web shell' {
    BeforeAll {
        $script:governanceProjectRoot = Split-Path -Parent $PSScriptRoot
    }

    It 'includes views object filters and relationship labels for every governance feature' {
        $index = Get-Content -LiteralPath (Join-Path $script:governanceProjectRoot 'Web\index.html') -Raw
        $app = Get-Content -LiteralPath (Join-Path $script:governanceProjectRoot 'Web\assets\app.js') -Raw

        foreach ($expectedIndexContract in @(
            'data-view="external"'
            'data-view="governance"'
            'value="administrativeUnit"'
            'value="accessPackage"'
            'value="accessReviewDefinition,accessReviewInstance"'
            'value="applicationManagementPolicy"'
            'value="crossTenantAccessPolicy,externalTenant"'
        )) {
            $index | Should -Match ([regex]::Escape($expectedIndexContract))
        }

        foreach ($expectedRelationship in @(
            'memberOfAdministrativeUnit'
            'pimActiveMember'
            'pimEligibleMember'
            'assignedAccessPackage'
            'reviewedInAccessReview'
            'governedByAppManagementPolicy'
            'hasCrossTenantPartner'
        )) {
            $app | Should -Match ([regex]::Escape($expectedRelationship))
        }

        $navKinds = @(
            [regex]::Matches($index, 'data-kind="([^"]+)"') |
                ForEach-Object { $_.Groups[1].Value } |
                Sort-Object -Unique
        )
        foreach ($navKind in $navKinds) {
            $index | Should -Match ([regex]::Escape("<option value=`"$navKind`">"))
        }
    }
}
