function Get-AtlasDirectoryRole {
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
    $nodeById = @{}
    foreach ($node in $KnownNode) {
        if (-not $keyById.ContainsKey($node.Id) -or $node.Status -eq 'complete') {
            $keyById[$node.Id] = $node.Key
            $nodeById[$node.Id] = $node
        }
    }

    $definitionsEndpoint = '/v1.0/roleManagement/directory/roleDefinitions?$select=id,displayName,description,isBuiltIn,isEnabled'
    $assignmentsEndpoint = '/v1.0/roleManagement/directory/roleAssignments?$select=id,principalId,roleDefinitionId,directoryScopeId'
    $eligibilityEndpoint = '/v1.0/roleManagement/directory/roleEligibilityScheduleInstances?$select=id,principalId,roleDefinitionId,directoryScopeId,startDateTime,endDateTime,memberType'
    $definitionResponse = Invoke-AtlasGraphRequest -Uri $definitionsEndpoint
    $assignmentResponse = Invoke-AtlasGraphRequest -Uri $assignmentsEndpoint
    try {
        $eligibilityResponse = Invoke-AtlasGraphRequest -Uri $eligibilityEndpoint
    }
    catch {
        $result.Status = 'partial'
        $result.Warnings.Add("PIM eligible role assignments could not be collected: $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
        $eligibilityResponse = [pscustomobject] @{
            Items = @()
            Metrics = @{ requestCount = 0; retryCount = 0 }
        }
    }

    $roleKeyById = @{}
    foreach ($definition in $definitionResponse.Items) {
        $roleNode = New-AtlasNode -TenantId $TenantId -Id $definition.id -Kind 'roleDefinition' -DisplayName $definition.displayName -Properties @{
            description = $definition.description
            isBuiltIn = $definition.isBuiltIn
            isEnabled = $definition.isEnabled
        } -Source @{
            provider = 'microsoftGraph'
            apiVersion = 'v1.0'
            odataType = '#microsoft.graph.unifiedRoleDefinition'
            resourcePath = "/roleManagement/directory/roleDefinitions/$($definition.id)"
            collector = 'directoryRoles'
        }
        $result.Nodes.Add($roleNode)
        $roleKeyById[$definition.id] = $roleNode.Key
    }

    foreach ($assignment in $assignmentResponse.Items) {
        $appScopeId = Get-AtlasResponseProperty -InputObject $assignment -Name 'appScopeId'
        if (-not $roleKeyById.ContainsKey($assignment.roleDefinitionId)) {
            $result.Status = 'partial'
            $result.Warnings.Add("Role definition '$($assignment.roleDefinitionId)' was not returned.")
            continue
        }

        if ($keyById.ContainsKey($assignment.principalId)) {
            $principalKey = $keyById[$assignment.principalId]
        }
        else {
            $principalNode = New-AtlasNode -TenantId $TenantId -Id $assignment.principalId -Kind 'directoryObject' -DisplayName $assignment.principalId -Status 'unresolved' -Source @{
                provider = 'microsoftGraph'
                apiVersion = 'v1.0'
                resourcePath = "/directoryObjects/$($assignment.principalId)"
                collector = 'directoryRoles'
            }
            $result.Nodes.Add($principalNode)
            $principalKey = $principalNode.Key
        }

        $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'directoryRoles' -Endpoint $assignmentsEndpoint -SourceObjectId $assignment.id -Fields @{
            principalId = $assignment.principalId
            roleDefinitionId = $assignment.roleDefinitionId
            directoryScopeId = $assignment.directoryScopeId
            appScopeId = $appScopeId
            activation = 'active'
        }
        $result.Evidence.Add($evidence)
        $result.Edges.Add(
            (New-AtlasEdge -TenantId $TenantId -From $principalKey -To $roleKeyById[$assignment.roleDefinitionId] -Relationship 'assignedRole' -State @{
                assignmentId = $assignment.id
                activation = 'active'
                assignment = if ($nodeById.ContainsKey($assignment.principalId) -and $nodeById[$assignment.principalId].Kind -eq 'group') {
                    'group'
                }
                else {
                    'direct'
                }
                directoryScopeId = $assignment.directoryScopeId
                appScopeId = $appScopeId
            } -EvidenceIds @($evidence.Key) -Source @{
                collector = 'directoryRoles'
            })
        )
    }

    foreach ($eligibility in $eligibilityResponse.Items) {
        $eligibilityStartDateTime = Get-AtlasResponseProperty -InputObject $eligibility -Name 'startDateTime'
        $eligibilityEndDateTime = Get-AtlasResponseProperty -InputObject $eligibility -Name 'endDateTime'
        $eligibilityMemberType = Get-AtlasResponseProperty -InputObject $eligibility -Name 'memberType'
        if (-not $roleKeyById.ContainsKey($eligibility.roleDefinitionId)) {
            $result.Status = 'partial'
            $result.Warnings.Add("Eligible role definition '$($eligibility.roleDefinitionId)' was not returned.")
            continue
        }

        if ($keyById.ContainsKey($eligibility.principalId)) {
            $principalKey = $keyById[$eligibility.principalId]
        }
        else {
            $principalNode = New-AtlasNode -TenantId $TenantId -Id $eligibility.principalId -Kind 'directoryObject' -DisplayName $eligibility.principalId -Status 'unresolved' -Source @{
                provider = 'microsoftGraph'
                apiVersion = 'v1.0'
                resourcePath = "/directoryObjects/$($eligibility.principalId)"
                collector = 'directoryRoleEligibility'
            }
            $result.Nodes.Add($principalNode)
            $principalKey = $principalNode.Key
        }

        $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'directoryRoleEligibility' -Endpoint $eligibilityEndpoint -SourceObjectId $eligibility.id -Fields @{
            principalId = $eligibility.principalId
            roleDefinitionId = $eligibility.roleDefinitionId
            directoryScopeId = $eligibility.directoryScopeId
            activation = 'eligible'
            startDateTime = $eligibilityStartDateTime
            endDateTime = $eligibilityEndDateTime
            memberType = $eligibilityMemberType
        }
        $result.Evidence.Add($evidence)
        $result.Edges.Add(
            (New-AtlasEdge -TenantId $TenantId -From $principalKey -To $roleKeyById[$eligibility.roleDefinitionId] -Relationship 'eligibleRole' -State @{
                assignmentId = $eligibility.id
                activation = 'eligible'
                assignment = if ($nodeById.ContainsKey($eligibility.principalId) -and $nodeById[$eligibility.principalId].Kind -eq 'group') {
                    'group'
                }
                else {
                    'direct'
                }
                directoryScopeId = $eligibility.directoryScopeId
                startDateTime = $eligibilityStartDateTime
                endDateTime = $eligibilityEndDateTime
                memberType = $eligibilityMemberType
            } -EvidenceIds @($evidence.Key) -Source @{
                collector = 'directoryRoleEligibility'
            })
        )
    }

    $result.Metrics = @{
        roleDefinitionCount = $definitionResponse.Items.Count
        roleAssignmentCount = $assignmentResponse.Items.Count
        roleEligibilityCount = $eligibilityResponse.Items.Count
        requestCount = $definitionResponse.Metrics.requestCount + $assignmentResponse.Metrics.requestCount + $eligibilityResponse.Metrics.requestCount
        retryCount = $definitionResponse.Metrics.retryCount + $assignmentResponse.Metrics.retryCount + $eligibilityResponse.Metrics.retryCount
    }
    return $result
}
