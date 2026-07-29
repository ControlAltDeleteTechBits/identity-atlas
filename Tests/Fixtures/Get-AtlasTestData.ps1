function Get-AtlasTestData {
    [CmdletBinding()]
    param()

    $tenantId = '00000000-0000-0000-0000-000000000001'
    $result = [AtlasCollectionResult]::new()

    $mark = New-AtlasNode -TenantId $tenantId -Id '10000000-0000-0000-0000-000000000001' -Kind 'user' -DisplayName 'Mark Oldham' -Properties @{
        userPrincipalName = 'mark.oldham@identityatlas.example'
        userType = 'Member'
        accountEnabled = $true
    } -Source @{
        provider = 'synthetic'
        apiVersion = 'fixture-v1'
        odataType = '#microsoft.graph.user'
        resourcePath = '/users/10000000-0000-0000-0000-000000000001'
        collector = 'sampleData'
    }

    $alex = New-AtlasNode -TenantId $tenantId -Id '10000000-0000-0000-0000-000000000002' -Kind 'user' -DisplayName 'Alex Wilkins' -Properties @{
        userPrincipalName = 'alex.wilkins@identityatlas.example'
        userType = 'Member'
        accountEnabled = $true
    } -Source @{
        provider = 'synthetic'
        apiVersion = 'fixture-v1'
        odataType = '#microsoft.graph.user'
        resourcePath = '/users/10000000-0000-0000-0000-000000000002'
        collector = 'sampleData'
    }

    $priya = New-AtlasNode -TenantId $tenantId -Id '10000000-0000-0000-0000-000000000003' -Kind 'user' -DisplayName 'Priya Shah' -Properties @{
        userPrincipalName = 'priya.shah@identityatlas.example'
        userType = 'Member'
        accountEnabled = $true
    } -Source @{
        provider = 'synthetic'
        apiVersion = 'fixture-v1'
        odataType = '#microsoft.graph.user'
        resourcePath = '/users/10000000-0000-0000-0000-000000000003'
        collector = 'sampleData'
    }

    $privilegedGroup = New-AtlasNode -TenantId $tenantId -Id '20000000-0000-0000-0000-000000000001' -Kind 'group' -DisplayName 'Privileged Access Operators' -Properties @{
        description = 'Fixture group used for a group-based role assignment.'
        securityEnabled = $true
        mailEnabled = $false
        isAssignableToRole = $true
        membershipRule = $null
    } -Source @{
        provider = 'synthetic'
        apiVersion = 'fixture-v1'
        odataType = '#microsoft.graph.group'
        resourcePath = '/groups/20000000-0000-0000-0000-000000000001'
        collector = 'sampleData'
    }

    $serviceDeskGroup = New-AtlasNode -TenantId $tenantId -Id '20000000-0000-0000-0000-000000000002' -Kind 'group' -DisplayName 'Service Desk Administrators' -Properties @{
        description = 'Fixture group used for a lower-privilege role assignment.'
        securityEnabled = $true
        mailEnabled = $false
        isAssignableToRole = $true
        membershipRule = $null
    } -Source @{
        provider = 'synthetic'
        apiVersion = 'fixture-v1'
        odataType = '#microsoft.graph.group'
        resourcePath = '/groups/20000000-0000-0000-0000-000000000002'
        collector = 'sampleData'
    }

    $globalAdmin = New-AtlasNode -TenantId $tenantId -Id '30000000-0000-0000-0000-000000000001' -Kind 'roleDefinition' -DisplayName 'Global Administrator' -Properties @{
        description = 'Fixture role definition.'
        isBuiltIn = $true
        isEnabled = $true
    } -Source @{
        provider = 'synthetic'
        apiVersion = 'fixture-v1'
        odataType = '#microsoft.graph.unifiedRoleDefinition'
        resourcePath = '/roleManagement/directory/roleDefinitions/30000000-0000-0000-0000-000000000001'
        collector = 'sampleData'
    }

    $userAdmin = New-AtlasNode -TenantId $tenantId -Id '30000000-0000-0000-0000-000000000002' -Kind 'roleDefinition' -DisplayName 'User Administrator' -Properties @{
        description = 'Fixture role definition.'
        isBuiltIn = $true
        isEnabled = $true
    } -Source @{
        provider = 'synthetic'
        apiVersion = 'fixture-v1'
        odataType = '#microsoft.graph.unifiedRoleDefinition'
        resourcePath = '/roleManagement/directory/roleDefinitions/30000000-0000-0000-0000-000000000002'
        collector = 'sampleData'
    }

    $financeApi = New-AtlasNode -TenantId $tenantId -Id '40000000-0000-0000-0000-000000000001' -Kind 'servicePrincipal' -DisplayName 'Contoso Finance API' -Properties @{
        appId = '50000000-0000-0000-0000-000000000001'
        servicePrincipalType = 'Application'
        accountEnabled = $true
        appRoleCount = 2
    } -Source @{
        provider = 'synthetic'
        apiVersion = 'fixture-v1'
        odataType = '#microsoft.graph.servicePrincipal'
        resourcePath = '/servicePrincipals/40000000-0000-0000-0000-000000000001'
        collector = 'sampleData'
    }

    $financeAppRegistration = New-AtlasNode -TenantId $tenantId -Id '40000000-0000-0000-0000-000000000101' -Kind 'application' -DisplayName 'Contoso Finance API registration' -Properties @{
        appId = '50000000-0000-0000-0000-000000000001'
        signInAudience = 'AzureADMyOrg'
        passwordCredentialCount = 1
        keyCredentialCount = 0
        requiredResourceAccessCount = 1
    } -Source @{
        provider = 'synthetic'
        apiVersion = 'fixture-v1'
        odataType = '#microsoft.graph.application'
        resourcePath = '/applications/40000000-0000-0000-0000-000000000101'
        collector = 'sampleData'
    }

    $financeCredential = New-AtlasNode -TenantId $tenantId -Id '40000000-0000-0000-0000-000000000101:passwordCredential:80000000-0000-0000-0000-000000000001' -Kind 'applicationCredential' -DisplayName 'Finance API client secret' -Properties @{
        credentialType = 'passwordCredential'
        keyId = '80000000-0000-0000-0000-000000000001'
        startDateTime = '2026-01-01T00:00:00Z'
        endDateTime = '2026-08-15T00:00:00Z'
    } -Source @{
        provider = 'synthetic'
        apiVersion = 'fixture-v1'
        odataType = '#microsoft.graph.passwordCredential'
        resourcePath = '/applications/40000000-0000-0000-0000-000000000101'
        collector = 'sampleData'
    } -Tags @('credential')

    $graphPermission = New-AtlasNode -TenantId $tenantId -Id 'apiPermission:00000003-0000-0000-c000-000000000000:df021288-bdef-4463-88db-98f22de89214:Role' -Kind 'apiPermission' -DisplayName 'Microsoft Graph User.Read.All' -Properties @{
        resourceAppId = '00000003-0000-0000-c000-000000000000'
        resourceAccessId = 'df021288-bdef-4463-88db-98f22de89214'
        permissionType = 'Role'
    } -Source @{
        provider = 'synthetic'
        apiVersion = 'fixture-v1'
        odataType = '#microsoft.graph.resourceAccess'
        resourcePath = '/applications/40000000-0000-0000-0000-000000000101'
        collector = 'sampleData'
    } -Tags @('apiPermission')

    $mfaPolicy = New-AtlasNode -TenantId $tenantId -Id '70000000-0000-0000-0000-000000000001' -Kind 'conditionalAccessPolicy' -DisplayName 'Require MFA for Finance API' -Properties @{
        state = 'enabled'
        includeUserCount = 1
        excludeUserCount = 0
        includeGroupCount = 0
        excludeGroupCount = 1
        includeApplicationCount = 1
        excludeApplicationCount = 0
        grantControls = @{
            operator = 'OR'
            builtInControls = @('mfa')
        }
        sessionControls = $null
    } -Source @{
        provider = 'synthetic'
        apiVersion = 'fixture-v1'
        odataType = '#microsoft.graph.conditionalAccessPolicy'
        resourcePath = '/identity/conditionalAccess/policies/70000000-0000-0000-0000-000000000001'
        collector = 'sampleData'
    }

    $surfaceLaptop = New-AtlasNode -TenantId $tenantId -Id '90000000-0000-0000-0000-000000000001' -Kind 'device' -DisplayName 'MARK-SURFACE-LAPTOP' -Properties @{
        deviceId = '90000000-0000-0000-0000-000000000101'
        operatingSystem = 'Windows'
        operatingSystemVersion = '11.0.26100'
        trustType = 'AzureAd'
        isCompliant = $true
        isManaged = $true
        accountEnabled = $true
        approximateLastSignInDateTime = '2026-07-25T09:30:00Z'
    } -Source @{
        provider = 'synthetic'
        apiVersion = 'fixture-v1'
        odataType = '#microsoft.graph.device'
        resourcePath = '/devices/90000000-0000-0000-0000-000000000001'
        collector = 'sampleData'
    }

    $authenticatorMethod = New-AtlasNode -TenantId $tenantId -Id '10000000-0000-0000-0000-000000000001:authenticationMethod:a0000000-0000-0000-0000-000000000001' -Kind 'authenticationMethod' -DisplayName 'microsoftAuthenticatorAuthenticationMethod' -Properties @{
        methodId = 'a0000000-0000-0000-0000-000000000001'
        methodType = 'microsoftAuthenticatorAuthenticationMethod'
        odataType = '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod'
    } -Source @{
        provider = 'synthetic'
        apiVersion = 'fixture-v1'
        odataType = '#microsoft.graph.microsoftAuthenticatorAuthenticationMethod'
        resourcePath = '/users/10000000-0000-0000-0000-000000000001/authentication/methods/a0000000-0000-0000-0000-000000000001'
        collector = 'sampleData'
    }

    $trustedLocation = New-AtlasNode -TenantId $tenantId -Id '71000000-0000-0000-0000-000000000001' -Kind 'namedLocation' -DisplayName 'Head Office trusted IPs' -Properties @{
        odataType = '#microsoft.graph.ipNamedLocation'
        isTrusted = $true
        createdDateTime = '2026-01-01T00:00:00Z'
        modifiedDateTime = '2026-07-01T00:00:00Z'
    } -Source @{
        provider = 'synthetic'
        apiVersion = 'fixture-v1'
        odataType = '#microsoft.graph.ipNamedLocation'
        resourcePath = '/identity/conditionalAccess/namedLocations/71000000-0000-0000-0000-000000000001'
        collector = 'sampleData'
    }

    $phishingResistantStrength = New-AtlasNode -TenantId $tenantId -Id '72000000-0000-0000-0000-000000000001' -Kind 'authenticationStrength' -DisplayName 'Phishing-resistant MFA' -Properties @{
        description = 'Fixture authentication strength used by the finance policy.'
        policyType = 'builtIn'
        requirementsSatisfied = 'mfa'
        allowedCombinations = @('fido2', 'windowsHelloForBusiness')
    } -Source @{
        provider = 'synthetic'
        apiVersion = 'fixture-v1'
        odataType = '#microsoft.graph.authenticationStrengthPolicy'
        resourcePath = '/policies/authenticationStrengthPolicies/72000000-0000-0000-0000-000000000001'
        collector = 'sampleData'
    }

    foreach ($node in @($mark, $alex, $priya, $privilegedGroup, $serviceDeskGroup, $globalAdmin, $userAdmin, $financeApi, $financeAppRegistration, $financeCredential, $graphPermission, $mfaPolicy, $surfaceLaptop, $authenticatorMethod, $trustedLocation, $phishingResistantStrength)) {
        $result.Nodes.Add($node)
    }

    $relationships = @(
        @{
            From = $mark
            To = $privilegedGroup
            Relationship = 'memberOf'
            State = @{ assignment = 'direct' }
            Endpoint = '/groups/20000000-0000-0000-0000-000000000001/members'
        }
        @{
            From = $alex
            To = $serviceDeskGroup
            Relationship = 'memberOf'
            State = @{ assignment = 'direct' }
            Endpoint = '/groups/20000000-0000-0000-0000-000000000002/members'
        }
        @{
            From = $privilegedGroup
            To = $globalAdmin
            Relationship = 'assignedRole'
            State = @{ assignment = 'group'; activation = 'active'; directoryScopeId = '/' }
            Endpoint = '/roleManagement/directory/roleAssignments'
        }
        @{
            From = $serviceDeskGroup
            To = $userAdmin
            Relationship = 'assignedRole'
            State = @{ assignment = 'group'; activation = 'active'; directoryScopeId = '/' }
            Endpoint = '/roleManagement/directory/roleAssignments'
        }
        @{
            From = $priya
            To = $userAdmin
            Relationship = 'assignedRole'
            State = @{ assignment = 'direct'; activation = 'active'; directoryScopeId = '/' }
            Endpoint = '/roleManagement/directory/roleAssignments'
        }
        @{
            From = $alex
            To = $globalAdmin
            Relationship = 'eligibleRole'
            State = @{ assignment = 'direct'; activation = 'eligible'; directoryScopeId = '/'; startDateTime = '2026-07-01T00:00:00Z'; endDateTime = '2026-12-31T23:59:59Z' }
            Endpoint = '/roleManagement/directory/roleEligibilityScheduleInstances'
        }
        @{
            From = $financeAppRegistration
            To = $financeApi
            Relationship = 'hasServicePrincipal'
            State = @{ appId = '50000000-0000-0000-0000-000000000001' }
            Endpoint = '/applications'
        }
        @{
            From = $financeAppRegistration
            To = $financeCredential
            Relationship = 'hasCredential'
            State = @{ credentialType = 'passwordCredential'; endDateTime = '2026-08-15T00:00:00Z' }
            Endpoint = '/applications'
        }
        @{
            From = $financeAppRegistration
            To = $graphPermission
            Relationship = 'requiresApiPermission'
            State = @{ resourceAppId = '00000003-0000-0000-c000-000000000000'; permissionType = 'Role' }
            Endpoint = '/applications'
        }
        @{
            From = $financeAppRegistration
            To = $mark
            Relationship = 'ownedBy'
            State = @{ ownerId = $mark.Id }
            Endpoint = '/applications/40000000-0000-0000-0000-000000000101/owners'
        }
        @{
            From = $financeApi
            To = $mark
            Relationship = 'ownedBy'
            State = @{ ownerId = $mark.Id }
            Endpoint = '/servicePrincipals/40000000-0000-0000-0000-000000000001/owners'
        }
        @{
            From = $serviceDeskGroup
            To = $priya
            Relationship = 'ownedBy'
            State = @{ ownerId = $priya.Id }
            Endpoint = '/groups/20000000-0000-0000-0000-000000000002/owners'
        }
        @{
            From = $mark
            To = $financeApi
            Relationship = 'assignedAppRole'
            State = @{
                assignment = 'direct'
                principalType = 'User'
                appRoleId = '60000000-0000-0000-0000-000000000001'
                appRoleDisplayName = 'Finance.Reader'
            }
            Endpoint = '/servicePrincipals/40000000-0000-0000-0000-000000000001/appRoleAssignedTo'
        }
        @{
            From = $serviceDeskGroup
            To = $financeApi
            Relationship = 'assignedAppRole'
            State = @{
                assignment = 'group'
                principalType = 'Group'
                appRoleId = '60000000-0000-0000-0000-000000000002'
                appRoleDisplayName = 'Finance.Approver'
            }
            Endpoint = '/servicePrincipals/40000000-0000-0000-0000-000000000001/appRoleAssignedTo'
        }
        @{
            From = $mark
            To = $mfaPolicy
            Relationship = 'conditionalAccessIncludes'
            State = @{ assignment = 'include'; category = 'users'; subjectKind = 'user'; policyState = 'enabled' }
            Endpoint = '/identity/conditionalAccess/policies'
        }
        @{
            From = $serviceDeskGroup
            To = $mfaPolicy
            Relationship = 'conditionalAccessExcludes'
            State = @{ assignment = 'exclude'; category = 'groups'; subjectKind = 'group'; policyState = 'enabled' }
            Endpoint = '/identity/conditionalAccess/policies'
        }
        @{
            From = $financeApi
            To = $mfaPolicy
            Relationship = 'conditionalAccessIncludes'
            State = @{ assignment = 'include'; category = 'applications'; subjectKind = 'application'; policyState = 'enabled' }
            Endpoint = '/identity/conditionalAccess/policies'
        }
        @{
            From = $mark
            To = $surfaceLaptop
            Relationship = 'registeredDevice'
            State = @{ assignment = 'registeredOwner' }
            Endpoint = '/devices/90000000-0000-0000-0000-000000000001/registeredOwners'
        }
        @{
            From = $mark
            To = $authenticatorMethod
            Relationship = 'hasAuthenticationMethod'
            State = @{ methodType = 'microsoftAuthenticatorAuthenticationMethod' }
            Endpoint = '/users/10000000-0000-0000-0000-000000000001/authentication/methods'
        }
        @{
            From = $mfaPolicy
            To = $trustedLocation
            Relationship = 'conditionalAccessIncludesLocation'
            State = @{ assignment = 'include' }
            Endpoint = '/identity/conditionalAccess/policies'
        }
        @{
            From = $mfaPolicy
            To = $phishingResistantStrength
            Relationship = 'requiresAuthenticationStrength'
            State = @{ authenticationStrengthId = $phishingResistantStrength.Id }
            Endpoint = '/identity/conditionalAccess/policies'
        }
    )

    foreach ($relationship in $relationships) {
        $evidence = New-AtlasEvidence -TenantId $tenantId -Collector 'sampleData' -Endpoint $relationship.Endpoint -SourceObjectId "$($relationship.From.Id)|$($relationship.Relationship)|$($relationship.To.Id)" -Fields @{
            fromId = $relationship.From.Id
            toId = $relationship.To.Id
            relationship = $relationship.Relationship
            state = $relationship.State
        }
        $result.Evidence.Add($evidence)
        $result.Edges.Add(
            (New-AtlasEdge -TenantId $tenantId -From $relationship.From.Key -To $relationship.To.Key -Relationship $relationship.Relationship -State $relationship.State -EvidenceIds @($evidence.Key) -Source @{
                collector = 'sampleData'
            })
        )
    }

    $result.Metrics = @{
        nodeCount = $result.Nodes.Count
        edgeCount = $result.Edges.Count
        evidenceCount = $result.Evidence.Count
    }

    return [pscustomobject] @{
        TenantId = $tenantId
        TenantDisplayName = 'Identity Atlas Development Fixture'
        Collection = $result
        Collectors = @(
            @{ name = 'sampleData'; status = 'complete'; itemCount = $result.Nodes.Count }
        )
    }
}
