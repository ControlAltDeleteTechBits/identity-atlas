function Get-AtlasEntitlementManagement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TenantId,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AtlasNode[]] $KnownNode
    )

    $result = [AtlasCollectionResult]::new()
    $keyById = @{}
    $keyByAppId = @{}
    $addedNode = @{}
    foreach ($node in $KnownNode) {
        $keyById[$node.Id] = $node.Key
        if ($node.Properties.ContainsKey('appId') -and $node.Properties.appId) {
            $keyByAppId[$node.Properties.appId] = $node.Key
        }
    }

    $catalogsEndpoint = '/v1.0/identityGovernance/entitlementManagement/catalogs?$select=id,displayName,description,catalogType,state,isExternallyVisible,createdDateTime,modifiedDateTime'
    $packagesEndpoint = '/v1.0/identityGovernance/entitlementManagement/accessPackages?$expand=catalog'
    $policiesEndpoint = '/v1.0/identityGovernance/entitlementManagement/assignmentPolicies?$expand=accessPackage'
    $assignmentsEndpoint = '/v1.0/identityGovernance/entitlementManagement/assignments?$expand=target,accessPackage'

    $catalogResponse = Invoke-AtlasGraphRequest -Uri $catalogsEndpoint
    $packageResponse = Invoke-AtlasGraphRequest -Uri $packagesEndpoint
    $policyResponse = Invoke-AtlasGraphRequest -Uri $policiesEndpoint
    $assignmentResponse = Invoke-AtlasGraphRequest -Uri $assignmentsEndpoint
    $requestCount = $catalogResponse.Metrics.requestCount + $packageResponse.Metrics.requestCount + $policyResponse.Metrics.requestCount + $assignmentResponse.Metrics.requestCount
    $retryCount = $catalogResponse.Metrics.retryCount + $packageResponse.Metrics.retryCount + $policyResponse.Metrics.retryCount + $assignmentResponse.Metrics.retryCount

    $catalogKeyById = @{}
    foreach ($catalog in $catalogResponse.Items) {
        $catalogNode = New-AtlasNode -TenantId $TenantId -Id "accessPackageCatalog:$($catalog.id)" -Kind 'accessPackageCatalog' -DisplayName $catalog.displayName -Properties @{
            catalogId = $catalog.id
            description = Get-AtlasResponseProperty -InputObject $catalog -Name 'description'
            catalogType = Get-AtlasResponseProperty -InputObject $catalog -Name 'catalogType'
            state = Get-AtlasResponseProperty -InputObject $catalog -Name 'state'
            isExternallyVisible = Get-AtlasResponseProperty -InputObject $catalog -Name 'isExternallyVisible'
            createdDateTime = Get-AtlasResponseProperty -InputObject $catalog -Name 'createdDateTime'
            modifiedDateTime = Get-AtlasResponseProperty -InputObject $catalog -Name 'modifiedDateTime'
        } -Source @{
            provider = 'microsoftGraph'
            apiVersion = 'v1.0'
            odataType = '#microsoft.graph.accessPackageCatalog'
            resourcePath = "/identityGovernance/entitlementManagement/catalogs/$($catalog.id)"
            collector = 'entitlementManagement'
        } -Tags @('governance', 'entitlementManagement')
        $result.Nodes.Add($catalogNode)
        $catalogKeyById[$catalog.id] = $catalogNode.Key
    }

    $packageKeyById = @{}
    $resourceRoleScopeCount = 0
    foreach ($package in $packageResponse.Items) {
        $catalog = Get-AtlasResponseProperty -InputObject $package -Name 'catalog'
        $catalogId = Get-AtlasResponseProperty -InputObject $catalog -Name 'id'
        $packageNode = New-AtlasNode -TenantId $TenantId -Id "accessPackage:$($package.id)" -Kind 'accessPackage' -DisplayName $package.displayName -Properties @{
            accessPackageId = $package.id
            description = Get-AtlasResponseProperty -InputObject $package -Name 'description'
            catalogId = $catalogId
            createdDateTime = Get-AtlasResponseProperty -InputObject $package -Name 'createdDateTime'
            modifiedDateTime = Get-AtlasResponseProperty -InputObject $package -Name 'modifiedDateTime'
            isHidden = Get-AtlasResponseProperty -InputObject $package -Name 'isHidden'
        } -Source @{
            provider = 'microsoftGraph'
            apiVersion = 'v1.0'
            odataType = '#microsoft.graph.accessPackage'
            resourcePath = "/identityGovernance/entitlementManagement/accessPackages/$($package.id)"
            collector = 'entitlementManagement'
        } -Tags @('governance', 'entitlementManagement')
        $result.Nodes.Add($packageNode)
        $packageKeyById[$package.id] = $packageNode.Key

        if ($catalogId -and $catalogKeyById.ContainsKey($catalogId)) {
            $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'entitlementManagement' -Endpoint $packagesEndpoint -SourceObjectId "$catalogId|$($package.id)" -Fields @{
                catalogId = $catalogId
                accessPackageId = $package.id
            }
            $result.Evidence.Add($evidence)
            $result.Edges.Add(
                (New-AtlasEdge -TenantId $TenantId -From $catalogKeyById[$catalogId] -To $packageNode.Key -Relationship 'containsAccessPackage' -EvidenceIds @($evidence.Key) -Source @{ collector = 'entitlementManagement' })
            )
        }

        $resourceEndpoint = "/v1.0/identityGovernance/entitlementManagement/accessPackages/$($package.id)?`$expand=resourceRoleScopes(`$expand=role,scope)"
        try {
            $resourceResponse = Invoke-AtlasGraphRequest -Uri $resourceEndpoint
            $requestCount += $resourceResponse.Metrics.requestCount
            $retryCount += $resourceResponse.Metrics.retryCount
        }
        catch {
            $result.Status = 'partial'
            $result.Warnings.Add("Resource roles could not be collected for access package '$($package.displayName)': $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
            continue
        }

        $expandedPackage = @($resourceResponse.Items)[0]
        $resourceRoleScopes = @(Get-AtlasResponseProperty -InputObject $expandedPackage -Name 'resourceRoleScopes')
        foreach ($resourceRoleScope in $resourceRoleScopes) {
            $role = Get-AtlasResponseProperty -InputObject $resourceRoleScope -Name 'role'
            $scope = Get-AtlasResponseProperty -InputObject $resourceRoleScope -Name 'scope'
            $originId = Get-AtlasResponseProperty -InputObject $scope -Name 'originId'
            if (-not $originId) {
                $originId = Get-AtlasResponseProperty -InputObject $role -Name 'originId'
            }
            $originSystem = Get-AtlasResponseProperty -InputObject $scope -Name 'originSystem'
            if (-not $originSystem) {
                $originSystem = Get-AtlasResponseProperty -InputObject $role -Name 'originSystem'
            }
            if (-not $originId) { continue }

            if ($keyById.ContainsKey($originId)) {
                $resourceKey = $keyById[$originId]
            }
            elseif ($keyByAppId.ContainsKey($originId)) {
                $resourceKey = $keyByAppId[$originId]
            }
            else {
                $resourceId = "entitlementResource:$originSystem`:$originId"
                $resourceKey = "tenant:$TenantId`:graph:$resourceId"
                if (-not $addedNode.ContainsKey($resourceKey)) {
                    $resourceName = Get-AtlasResponseProperty -InputObject $scope -Name 'displayName'
                    if (-not $resourceName) { $resourceName = $originId }
                    $resourceNode = New-AtlasNode -TenantId $TenantId -Id $resourceId -Kind 'entitlementResource' -DisplayName $resourceName -Properties @{
                        originId = $originId
                        originSystem = $originSystem
                    } -Source @{
                        provider = 'microsoftGraph'
                        apiVersion = 'v1.0'
                        odataType = '#microsoft.graph.accessPackageResourceScope'
                        resourcePath = "/identityGovernance/entitlementManagement/accessPackages/$($package.id)"
                        collector = 'entitlementManagement'
                    } -Tags @('governance', 'entitlementResource')
                    $result.Nodes.Add($resourceNode)
                    $addedNode[$resourceKey] = $true
                }
            }

            $resourceRoleScopeId = Get-AtlasResponseProperty -InputObject $resourceRoleScope -Name 'id'
            if (-not $resourceRoleScopeId) {
                $resourceRoleScopeId = "$($package.id)|$originId|$(Get-AtlasResponseProperty -InputObject $role -Name 'originId')"
            }
            $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'entitlementManagement' -Endpoint $resourceEndpoint -SourceObjectId $resourceRoleScopeId -Fields @{
                accessPackageId = $package.id
                resourceOriginId = $originId
                resourceOriginSystem = $originSystem
                roleOriginId = Get-AtlasResponseProperty -InputObject $role -Name 'originId'
                roleDisplayName = Get-AtlasResponseProperty -InputObject $role -Name 'displayName'
                scopeDisplayName = Get-AtlasResponseProperty -InputObject $scope -Name 'displayName'
            }
            $result.Evidence.Add($evidence)
            $result.Edges.Add(
                (New-AtlasEdge -TenantId $TenantId -From $packageNode.Key -To $resourceKey -Relationship 'grantsEntitlementResourceRole' -State @{
                    roleDisplayName = Get-AtlasResponseProperty -InputObject $role -Name 'displayName'
                    roleOriginId = Get-AtlasResponseProperty -InputObject $role -Name 'originId'
                    originSystem = $originSystem
                } -EvidenceIds @($evidence.Key) -Source @{ collector = 'entitlementManagement' })
            )
            $resourceRoleScopeCount++
        }
    }

    $policyKeyById = @{}
    foreach ($policy in $policyResponse.Items) {
        $accessPackage = Get-AtlasResponseProperty -InputObject $policy -Name 'accessPackage'
        $accessPackageId = Get-AtlasResponseProperty -InputObject $accessPackage -Name 'id'
        if (-not $accessPackageId) {
            $accessPackageId = Get-AtlasResponseProperty -InputObject $policy -Name 'accessPackageId'
        }
        $policyNode = New-AtlasNode -TenantId $TenantId -Id "accessPackageAssignmentPolicy:$($policy.id)" -Kind 'accessPackageAssignmentPolicy' -DisplayName $policy.displayName -Properties @{
            assignmentPolicyId = $policy.id
            description = Get-AtlasResponseProperty -InputObject $policy -Name 'description'
            accessPackageId = $accessPackageId
            allowedTargetScope = Get-AtlasResponseProperty -InputObject $policy -Name 'allowedTargetScope'
            canExtend = Get-AtlasResponseProperty -InputObject $policy -Name 'canExtend'
            expiration = Get-AtlasResponseProperty -InputObject $policy -Name 'expiration'
            requestApprovalSettings = Get-AtlasResponseProperty -InputObject $policy -Name 'requestApprovalSettings'
            reviewSettings = Get-AtlasResponseProperty -InputObject $policy -Name 'reviewSettings'
            createdDateTime = Get-AtlasResponseProperty -InputObject $policy -Name 'createdDateTime'
            modifiedDateTime = Get-AtlasResponseProperty -InputObject $policy -Name 'modifiedDateTime'
        } -Source @{
            provider = 'microsoftGraph'
            apiVersion = 'v1.0'
            odataType = '#microsoft.graph.accessPackageAssignmentPolicy'
            resourcePath = "/identityGovernance/entitlementManagement/assignmentPolicies/$($policy.id)"
            collector = 'entitlementManagement'
        } -Tags @('governance', 'entitlementManagement')
        $result.Nodes.Add($policyNode)
        $policyKeyById[$policy.id] = $policyNode.Key

        if ($accessPackageId -and $packageKeyById.ContainsKey($accessPackageId)) {
            $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'entitlementManagement' -Endpoint $policiesEndpoint -SourceObjectId "$accessPackageId|$($policy.id)" -Fields @{
                accessPackageId = $accessPackageId
                assignmentPolicyId = $policy.id
            }
            $result.Evidence.Add($evidence)
            $result.Edges.Add(
                (New-AtlasEdge -TenantId $TenantId -From $packageKeyById[$accessPackageId] -To $policyNode.Key -Relationship 'governedByAccessPackagePolicy' -EvidenceIds @($evidence.Key) -Source @{ collector = 'entitlementManagement' })
            )
        }
    }

    $assignmentCount = 0
    foreach ($assignment in $assignmentResponse.Items) {
        $target = Get-AtlasResponseProperty -InputObject $assignment -Name 'target'
        $accessPackage = Get-AtlasResponseProperty -InputObject $assignment -Name 'accessPackage'
        $targetId = Get-AtlasResponseProperty -InputObject $target -Name 'objectId'
        if (-not $targetId) { $targetId = Get-AtlasResponseProperty -InputObject $assignment -Name 'targetId' }
        $accessPackageId = Get-AtlasResponseProperty -InputObject $accessPackage -Name 'id'
        if (-not $accessPackageId) { $accessPackageId = Get-AtlasResponseProperty -InputObject $assignment -Name 'accessPackageId' }
        if (-not $targetId -or -not $packageKeyById.ContainsKey($accessPackageId)) {
            $result.Status = 'partial'
            $result.Warnings.Add("Entitlement assignment '$($assignment.id)' could not be connected to both a subject and access package.")
            continue
        }

        if ($keyById.ContainsKey($targetId)) {
            $targetKey = $keyById[$targetId]
        }
        else {
            $targetKey = "tenant:$TenantId`:graph:$targetId"
            if (-not $addedNode.ContainsKey($targetKey)) {
                $targetName = Get-AtlasResponseProperty -InputObject $target -Name 'displayName'
                if (-not $targetName) { $targetName = $targetId }
                $targetNode = New-AtlasNode -TenantId $TenantId -Id $targetId -Kind 'entitlementSubject' -DisplayName $targetName -Status 'partial' -Properties @{
                    email = Get-AtlasResponseProperty -InputObject $target -Name 'email'
                    subjectType = Get-AtlasResponseProperty -InputObject $target -Name 'subjectType'
                } -Source @{
                    provider = 'microsoftGraph'
                    apiVersion = 'v1.0'
                    odataType = '#microsoft.graph.accessPackageSubject'
                    resourcePath = "/identityGovernance/entitlementManagement/assignments/$($assignment.id)"
                    collector = 'entitlementManagement'
                }
                $result.Nodes.Add($targetNode)
                $addedNode[$targetKey] = $true
            }
        }

        $schedule = Get-AtlasResponseProperty -InputObject $assignment -Name 'schedule'
        $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'entitlementManagement' -Endpoint $assignmentsEndpoint -SourceObjectId $assignment.id -Fields @{
            assignmentId = $assignment.id
            targetId = $targetId
            accessPackageId = $accessPackageId
            assignmentPolicyId = Get-AtlasResponseProperty -InputObject $assignment -Name 'assignmentPolicyId'
            state = Get-AtlasResponseProperty -InputObject $assignment -Name 'state'
            status = Get-AtlasResponseProperty -InputObject $assignment -Name 'status'
            schedule = $schedule
            expiredDateTime = Get-AtlasResponseProperty -InputObject $assignment -Name 'expiredDateTime'
        }
        $result.Evidence.Add($evidence)
        $result.Edges.Add(
            (New-AtlasEdge -TenantId $TenantId -From $targetKey -To $packageKeyById[$accessPackageId] -Relationship 'assignedAccessPackage' -State @{
                assignmentId = $assignment.id
                assignmentPolicyId = Get-AtlasResponseProperty -InputObject $assignment -Name 'assignmentPolicyId'
                state = Get-AtlasResponseProperty -InputObject $assignment -Name 'state'
                status = Get-AtlasResponseProperty -InputObject $assignment -Name 'status'
                schedule = $schedule
                expiredDateTime = Get-AtlasResponseProperty -InputObject $assignment -Name 'expiredDateTime'
            } -EvidenceIds @($evidence.Key) -Source @{ collector = 'entitlementManagement' })
        )
        $assignmentCount++
    }

    $result.Metrics = @{
        catalogCount = $catalogResponse.Items.Count
        accessPackageCount = $packageResponse.Items.Count
        assignmentPolicyCount = $policyResponse.Items.Count
        assignmentCount = $assignmentCount
        resourceRoleScopeCount = $resourceRoleScopeCount
        requestCount = $requestCount
        retryCount = $retryCount
    }
    return $result
}
