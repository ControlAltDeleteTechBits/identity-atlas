function Get-AtlasApplication {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TenantId,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AtlasNode[]] $KnownNode,

        [switch] $SkipAppRoleAssignments,

        [switch] $SkipOwners,

        [ValidateRange(1, 20)]
        [int] $BatchSize = 10
    )

    $result = [AtlasCollectionResult]::new()
    $keyById = @{}
    $nodeById = @{}
    $nodeByAppId = @{}
    foreach ($node in $KnownNode) {
        if (-not $keyById.ContainsKey($node.Id) -or $node.Status -eq 'complete') {
            $keyById[$node.Id] = $node.Key
            $nodeById[$node.Id] = $node
        }
        if ($node.Properties.ContainsKey('appId') -and $node.Properties.appId) {
            $nodeByAppId[$node.Properties.appId] = $node
        }
    }

    $servicePrincipalsEndpoint = '/v1.0/servicePrincipals?$select=id,appId,displayName,servicePrincipalType,accountEnabled,appOwnerOrganizationId,appRoles'
    $applicationsEndpoint = '/v1.0/applications?$select=id,appId,displayName,signInAudience,createdDateTime,passwordCredentials,keyCredentials,requiredResourceAccess'
    try {
        $servicePrincipalResponse = Invoke-AtlasGraphRequest -Uri $servicePrincipalsEndpoint
    }
    catch {
        $result.Status = 'partial'
        $result.Warnings.Add("Applications could not be collected: $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
        $result.Metrics = @{
            servicePrincipalCount = 0
            applicationCount = 0
            appRoleAssignmentCount = 0
            ownerCount = 0
            credentialCount = 0
            apiPermissionCount = 0
            requestCount = 0
            retryCount = 0
        }
        return $result
    }
    try {
        $applicationResponse = Invoke-AtlasGraphRequest -Uri $applicationsEndpoint
    }
    catch {
        $result.Status = 'partial'
        $result.Warnings.Add("Application registrations could not be collected: $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
        $applicationResponse = [pscustomobject] @{
            Items = @()
            Metrics = @{ requestCount = 0; retryCount = 0 }
        }
    }

    $servicePrincipalKeyById = @{}
    $servicePrincipalKeyByAppId = @{}
    $applicationKeyById = @{}
    $applicationKeyByAppId = @{}
    $appRoleNameByPrincipalId = @{}
    $ownerEdgeCount = 0
    $appRoleAssignmentCount = 0
    $credentialCount = 0
    $apiPermissionCount = 0

    foreach ($servicePrincipal in $servicePrincipalResponse.Items) {
        $displayName = if ($servicePrincipal.displayName) { $servicePrincipal.displayName } else { $servicePrincipal.id }
        $appRoles = @($servicePrincipal.appRoles)
        $appRoleNames = @{}
        foreach ($appRole in $appRoles) {
            if ($appRole.id) {
                $appRoleNames[$appRole.id] = if ($appRole.displayName) { $appRole.displayName } else { $appRole.value }
            }
        }

        $node = New-AtlasNode -TenantId $TenantId -Id $servicePrincipal.id -Kind 'servicePrincipal' -DisplayName $displayName -Properties @{
            appId = $servicePrincipal.appId
            servicePrincipalType = $servicePrincipal.servicePrincipalType
            accountEnabled = $servicePrincipal.accountEnabled
            appOwnerOrganizationId = $servicePrincipal.appOwnerOrganizationId
            appRoleCount = $appRoles.Count
        } -Source @{
            provider = 'microsoftGraph'
            apiVersion = 'v1.0'
            odataType = '#microsoft.graph.servicePrincipal'
            resourcePath = "/servicePrincipals/$($servicePrincipal.id)"
            collector = 'applications'
        }
        $result.Nodes.Add($node)
        $servicePrincipalKeyById[$servicePrincipal.id] = $node.Key
        if ($servicePrincipal.appId) {
            $servicePrincipalKeyByAppId[$servicePrincipal.appId] = $node.Key
        }
        $appRoleNameByPrincipalId[$servicePrincipal.id] = $appRoleNames
    }

    foreach ($application in $applicationResponse.Items) {
        $passwordCredentials = @(
            @(Get-AtlasResponseProperty -InputObject $application -Name 'passwordCredentials') |
                Where-Object { $null -ne $_ }
        )
        $keyCredentials = @(
            @(Get-AtlasResponseProperty -InputObject $application -Name 'keyCredentials') |
                Where-Object { $null -ne $_ }
        )
        $requiredResourceAccess = @(
            @(Get-AtlasResponseProperty -InputObject $application -Name 'requiredResourceAccess') |
                Where-Object { $null -ne $_ }
        )
        $displayName = if ($application.displayName) { $application.displayName } else { $application.id }
        $applicationNode = New-AtlasNode -TenantId $TenantId -Id $application.id -Kind 'application' -DisplayName $displayName -Properties @{
            appId = $application.appId
            signInAudience = Get-AtlasResponseProperty -InputObject $application -Name 'signInAudience'
            createdDateTime = Get-AtlasResponseProperty -InputObject $application -Name 'createdDateTime'
            passwordCredentialCount = $passwordCredentials.Count
            keyCredentialCount = $keyCredentials.Count
            requiredResourceAccessCount = $requiredResourceAccess.Count
        } -Source @{
            provider = 'microsoftGraph'
            apiVersion = 'v1.0'
            odataType = '#microsoft.graph.application'
            resourcePath = "/applications/$($application.id)"
            collector = 'applications'
        }
        $result.Nodes.Add($applicationNode)
        $applicationKeyById[$application.id] = $applicationNode.Key
        if ($application.appId) {
            $applicationKeyByAppId[$application.appId] = $applicationNode.Key
        }

        if ($application.appId -and $servicePrincipalKeyByAppId.ContainsKey($application.appId)) {
            $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'applications' -Endpoint $applicationsEndpoint -SourceObjectId "$($application.id)|backingServicePrincipal|$($application.appId)" -Fields @{
                applicationId = $application.id
                appId = $application.appId
                relationship = 'hasServicePrincipal'
            }
            $result.Evidence.Add($evidence)
            $result.Edges.Add(
                (New-AtlasEdge -TenantId $TenantId -From $applicationNode.Key -To $servicePrincipalKeyByAppId[$application.appId] -Relationship 'hasServicePrincipal' -State @{
                    appId = $application.appId
                } -EvidenceIds @($evidence.Key) -Source @{
                    collector = 'applications'
                })
            )
        }

        foreach ($credential in $passwordCredentials + $keyCredentials) {
            $credentialKind = if ($passwordCredentials -contains $credential) { 'passwordCredential' } else { 'keyCredential' }
            $credentialId = "$($application.id):$credentialKind`:$($credential.keyId)"
            $credentialName = if ($credential.displayName) { $credential.displayName } else { $credentialKind }
            $credentialNode = New-AtlasNode -TenantId $TenantId -Id $credentialId -Kind 'applicationCredential' -DisplayName $credentialName -Properties @{
                credentialType = $credentialKind
                keyId = $credential.keyId
                startDateTime = $credential.startDateTime
                endDateTime = $credential.endDateTime
            } -Source @{
                provider = 'microsoftGraph'
                apiVersion = 'v1.0'
                odataType = "#microsoft.graph.$credentialKind"
                resourcePath = "/applications/$($application.id)"
                collector = 'applications'
            } -Tags @('credential')
            $result.Nodes.Add($credentialNode)
            $credentialCount++
            $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'applications' -Endpoint $applicationsEndpoint -SourceObjectId "$($application.id)|credential|$($credential.keyId)" -Fields @{
                applicationId = $application.id
                keyId = $credential.keyId
                credentialType = $credentialKind
                endDateTime = $credential.endDateTime
            }
            $result.Evidence.Add($evidence)
            $result.Edges.Add(
                (New-AtlasEdge -TenantId $TenantId -From $applicationNode.Key -To $credentialNode.Key -Relationship 'hasCredential' -State @{
                    credentialType = $credentialKind
                    endDateTime = $credential.endDateTime
                } -EvidenceIds @($evidence.Key) -Source @{
                    collector = 'applications'
                })
            )
        }

        foreach ($resourceAccess in $requiredResourceAccess) {
            foreach ($permission in @($resourceAccess.resourceAccess)) {
                if (-not $permission.id) {
                    continue
                }
                $permissionId = "$($resourceAccess.resourceAppId):$($permission.id):$($permission.type)"
                $permissionNode = New-AtlasNode -TenantId $TenantId -Id "apiPermission:$permissionId" -Kind 'apiPermission' -DisplayName "API permission $($permission.type) $($permission.id)" -Properties @{
                    resourceAppId = $resourceAccess.resourceAppId
                    resourceAccessId = $permission.id
                    permissionType = $permission.type
                } -Source @{
                    provider = 'microsoftGraph'
                    apiVersion = 'v1.0'
                    odataType = '#microsoft.graph.resourceAccess'
                    resourcePath = "/applications/$($application.id)"
                    collector = 'applications'
                } -Tags @('apiPermission')
                $result.Nodes.Add($permissionNode)
                $apiPermissionCount++
                $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'applications' -Endpoint $applicationsEndpoint -SourceObjectId "$($application.id)|requiredResourceAccess|$permissionId" -Fields @{
                    applicationId = $application.id
                    resourceAppId = $resourceAccess.resourceAppId
                    resourceAccessId = $permission.id
                    permissionType = $permission.type
                }
                $result.Evidence.Add($evidence)
                $result.Edges.Add(
                    (New-AtlasEdge -TenantId $TenantId -From $applicationNode.Key -To $permissionNode.Key -Relationship 'requiresApiPermission' -State @{
                        resourceAppId = $resourceAccess.resourceAppId
                        permissionType = $permission.type
                    } -EvidenceIds @($evidence.Key) -Source @{
                        collector = 'applications'
                    })
                )
            }
        }
    }

    $applicationLogicalRequestCount = 0
    if ($SkipAppRoleAssignments) {
        $result.Status = 'partial'
        $result.Warnings.Add('Application role assignment collection was skipped by request.')
        Update-AtlasProgressItem `
            -CurrentItem $servicePrincipalResponse.Items.Count `
            -TotalItems $servicePrincipalResponse.Items.Count `
            -Status 'Application role assignments skipped'
    }
    elseif ($servicePrincipalResponse.Items.Count -gt 0) {
        $servicePrincipalByBatchId = @{}
        $assignmentRequest = @(
            for ($index = 0; $index -lt $servicePrincipalResponse.Items.Count; $index++) {
                $batchId = "assignment-$index"
                $servicePrincipalByBatchId[$batchId] = $servicePrincipalResponse.Items[$index]
                [pscustomobject] @{
                    Id = $batchId
                    Uri = "/v1.0/servicePrincipals/$($servicePrincipalResponse.Items[$index].id)/appRoleAssignedTo?`$select=id,principalId,principalDisplayName,principalType,resourceId,resourceDisplayName,appRoleId,createdDateTime"
                }
            }
        )
        $assignmentBatch = Invoke-AtlasGraphBatchGet `
            -Request $assignmentRequest `
            -BatchSize $BatchSize `
            -ProgressStatus 'Application role assignments'
        $servicePrincipalResponse.Metrics.requestCount += $assignmentBatch.Metrics.requestCount
        $servicePrincipalResponse.Metrics.retryCount += $assignmentBatch.Metrics.retryCount
        $applicationLogicalRequestCount += $assignmentBatch.Metrics.logicalRequestCount

        foreach ($assignmentResponse in $assignmentBatch.Responses) {
            $servicePrincipal = $servicePrincipalByBatchId[$assignmentResponse.Id]
            $assignmentsEndpoint = $assignmentResponse.Uri
            if ($assignmentResponse.StatusCode -lt 200 -or $assignmentResponse.StatusCode -ge 300) {
                $result.Status = 'partial'
                $result.Warnings.Add("App role assignments could not be collected for application '$($servicePrincipal.displayName)': $($assignmentResponse.ErrorMessage)")
                continue
            }

            foreach ($assignment in $assignmentResponse.Items) {
                if (-not $servicePrincipalKeyById.ContainsKey($assignment.resourceId)) {
                    $result.Status = 'partial'
                    $result.Warnings.Add("Application '$($assignment.resourceId)' was referenced by an app role assignment but was not returned.")
                    continue
                }

                if ($keyById.ContainsKey($assignment.principalId)) {
                    $principalKey = $keyById[$assignment.principalId]
                }
                else {
                    $principalKind = switch ($assignment.principalType) {
                        'User' { 'user' }
                        'Group' { 'group' }
                        'ServicePrincipal' { 'servicePrincipal' }
                        default { 'directoryObject' }
                    }
                    $principalDisplayName = if ($assignment.principalDisplayName) { $assignment.principalDisplayName } else { $assignment.principalId }
                    $principalNode = New-AtlasNode -TenantId $TenantId -Id $assignment.principalId -Kind $principalKind -DisplayName $principalDisplayName -Status 'unresolved' -Source @{
                        provider = 'microsoftGraph'
                        apiVersion = 'v1.0'
                        resourcePath = "/directoryObjects/$($assignment.principalId)"
                        collector = 'applications'
                    }
                    $result.Nodes.Add($principalNode)
                    $principalKey = $principalNode.Key
                }

                $appRoleName = $null
                if (
                    $appRoleNameByPrincipalId.ContainsKey($assignment.resourceId) -and
                    $appRoleNameByPrincipalId[$assignment.resourceId].ContainsKey($assignment.appRoleId)
                ) {
                    $appRoleName = $appRoleNameByPrincipalId[$assignment.resourceId][$assignment.appRoleId]
                }

                $assignmentKind = if ($nodeById.ContainsKey($assignment.principalId) -and $nodeById[$assignment.principalId].Kind -eq 'group') {
                    'group'
                }
                else {
                    'direct'
                }

                $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'applications' -Endpoint $assignmentsEndpoint -SourceObjectId $assignment.id -Fields @{
                    principalId = $assignment.principalId
                    principalType = $assignment.principalType
                    resourceId = $assignment.resourceId
                    appRoleId = $assignment.appRoleId
                    appRoleDisplayName = $appRoleName
                    createdDateTime = $assignment.createdDateTime
                }
                $result.Evidence.Add($evidence)
                $result.Edges.Add(
                    (New-AtlasEdge -TenantId $TenantId -From $principalKey -To $servicePrincipalKeyById[$assignment.resourceId] -Relationship 'assignedAppRole' -State @{
                        assignment = $assignmentKind
                        principalType = $assignment.principalType
                        appRoleId = $assignment.appRoleId
                        appRoleDisplayName = $appRoleName
                        createdDateTime = $assignment.createdDateTime
                    } -EvidenceIds @($evidence.Key) -Source @{
                        collector = 'applications'
                    })
                )
                $appRoleAssignmentCount++
            }
        }
    }

    $ownerTargets = @()
    foreach ($applicationId in $applicationKeyById.Keys) {
        $ownerTargets += @{
            Id = $applicationId
            Key = $applicationKeyById[$applicationId]
            Endpoint = "/v1.0/applications/$applicationId/owners?`$select=id,displayName"
            Name = 'application'
        }
    }
    foreach ($servicePrincipalId in $servicePrincipalKeyById.Keys) {
        $ownerTargets += @{
            Id = $servicePrincipalId
            Key = $servicePrincipalKeyById[$servicePrincipalId]
            Endpoint = "/v1.0/servicePrincipals/$servicePrincipalId/owners?`$select=id,displayName"
            Name = 'service principal'
        }
    }

    if ($SkipOwners) {
        $result.Status = 'partial'
        $result.Warnings.Add('Application and service principal owner collection was skipped by request.')
        Update-AtlasProgressItem `
            -CurrentItem $ownerTargets.Count `
            -TotalItems $ownerTargets.Count `
            -Status 'Application owners skipped'
    }
    elseif ($ownerTargets.Count -gt 0) {
        $ownerTargetByBatchId = @{}
        $ownerRequest = @(
            for ($index = 0; $index -lt $ownerTargets.Count; $index++) {
                $batchId = "owner-$index"
                $ownerTargetByBatchId[$batchId] = $ownerTargets[$index]
                [pscustomobject] @{
                    Id = $batchId
                    Uri = $ownerTargets[$index].Endpoint
                }
            }
        )
        $ownerBatch = Invoke-AtlasGraphBatchGet `
            -Request $ownerRequest `
            -BatchSize $BatchSize `
            -ProgressStatus 'Application owners'
        $servicePrincipalResponse.Metrics.requestCount += $ownerBatch.Metrics.requestCount
        $servicePrincipalResponse.Metrics.retryCount += $ownerBatch.Metrics.retryCount
        $applicationLogicalRequestCount += $ownerBatch.Metrics.logicalRequestCount

        foreach ($ownerResponse in $ownerBatch.Responses) {
            $target = $ownerTargetByBatchId[$ownerResponse.Id]
            if ($ownerResponse.StatusCode -lt 200 -or $ownerResponse.StatusCode -ge 300) {
                $result.Status = 'partial'
                $result.Warnings.Add("Owners could not be collected for $($target.Name) '$($target.Id)': $($ownerResponse.ErrorMessage)")
                continue
            }

            foreach ($owner in $ownerResponse.Items) {
            $ownerId = Get-AtlasResponseProperty -InputObject $owner -Name 'id'
            if (-not $ownerId) {
                continue
            }
            if ($keyById.ContainsKey($ownerId)) {
                $ownerKey = $keyById[$ownerId]
            }
            elseif ($servicePrincipalKeyById.ContainsKey($ownerId)) {
                $ownerKey = $servicePrincipalKeyById[$ownerId]
            }
            elseif ($applicationKeyById.ContainsKey($ownerId)) {
                $ownerKey = $applicationKeyById[$ownerId]
            }
            else {
                $odataType = Get-AtlasResponseProperty -InputObject $owner -Name '@odata.type'
                $ownerKind = switch ($odataType) {
                    '#microsoft.graph.user' { 'user' }
                    '#microsoft.graph.group' { 'group' }
                    '#microsoft.graph.servicePrincipal' { 'servicePrincipal' }
                    default { 'directoryObject' }
                }
                $ownerName = Get-AtlasResponseProperty -InputObject $owner -Name 'displayName'
                if (-not $ownerName) { $ownerName = $ownerId }
                $ownerNode = New-AtlasNode -TenantId $TenantId -Id $ownerId -Kind $ownerKind -DisplayName $ownerName -Status 'unresolved' -Source @{
                    provider = 'microsoftGraph'
                    apiVersion = 'v1.0'
                    odataType = $odataType
                    resourcePath = "/directoryObjects/$ownerId"
                    collector = 'applications'
                }
                $result.Nodes.Add($ownerNode)
                $ownerKey = $ownerNode.Key
            }

            $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'applications' -Endpoint $target.Endpoint -SourceObjectId "$($target.Id)|owner|$ownerId" -Fields @{
                ownedObjectId = $target.Id
                ownerId = $ownerId
            }
            $result.Evidence.Add($evidence)
            $result.Edges.Add(
                (New-AtlasEdge -TenantId $TenantId -From $target.Key -To $ownerKey -Relationship 'ownedBy' -State @{
                    ownerId = $ownerId
                } -EvidenceIds @($evidence.Key) -Source @{
                    collector = 'applications'
                })
            )
                $ownerEdgeCount++
            }
        }
    }

    $result.Metrics = @{
        servicePrincipalCount = $servicePrincipalResponse.Items.Count
        applicationCount = $applicationResponse.Items.Count
        appRoleAssignmentCount = $appRoleAssignmentCount
        ownerCount = $ownerEdgeCount
        credentialCount = $credentialCount
        apiPermissionCount = $apiPermissionCount
        applicationLogicalRequestCount = $applicationLogicalRequestCount
        appRoleAssignmentsSkipped = [bool] $SkipAppRoleAssignments
        ownersSkipped = [bool] $SkipOwners
        batchSize = $BatchSize
        requestCount = $servicePrincipalResponse.Metrics.requestCount + $applicationResponse.Metrics.requestCount
        retryCount = $servicePrincipalResponse.Metrics.retryCount + $applicationResponse.Metrics.retryCount
    }
    return $result
}
