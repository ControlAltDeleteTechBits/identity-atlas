function Get-AtlasGroup {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TenantId
    )

    $result = [AtlasCollectionResult]::new()
    $endpoint = '/v1.0/groups?$select=id,displayName,description,groupTypes,mailEnabled,securityEnabled,isAssignableToRole,membershipRule'
    $response = Invoke-AtlasGraphRequest -Uri $endpoint

    foreach ($group in $response.Items) {
        $groupNode = New-AtlasNode -TenantId $TenantId -Id $group.id -Kind 'group' -DisplayName $group.displayName -Properties @{
            description = $group.description
            groupTypes = @($group.groupTypes)
            mailEnabled = $group.mailEnabled
            securityEnabled = $group.securityEnabled
            isAssignableToRole = $group.isAssignableToRole
            membershipRule = $group.membershipRule
        } -Source @{
            provider = 'microsoftGraph'
            apiVersion = 'v1.0'
            odataType = '#microsoft.graph.group'
            resourcePath = "/groups/$($group.id)"
            collector = 'groups'
        }
        $result.Nodes.Add($groupNode)

        $membersEndpoint = "/v1.0/groups/$($group.id)/members?`$select=id,displayName"
        try {
            $membersResponse = Invoke-AtlasGraphRequest -Uri $membersEndpoint
        }
        catch {
            $result.Status = 'partial'
            $result.Warnings.Add("Members could not be collected for group '$($group.displayName)': $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
            continue
        }

        foreach ($member in $membersResponse.Items) {
            $memberId = Get-AtlasResponseProperty -InputObject $member -Name 'id'
            if (-not $memberId) {
                $result.Status = 'partial'
                $result.Warnings.Add("A member returned for group '$($group.displayName)' did not include an ID and was skipped.")
                continue
            }

            $odataType = Get-AtlasResponseProperty -InputObject $member -Name '@odata.type'
            $memberDisplayName = Get-AtlasResponseProperty -InputObject $member -Name 'displayName'
            $memberKind = switch ($odataType) {
                '#microsoft.graph.user' { 'user' }
                '#microsoft.graph.group' { 'group' }
                '#microsoft.graph.servicePrincipal' { 'servicePrincipal' }
                '#microsoft.graph.device' { 'device' }
                default { 'directoryObject' }
            }

            $memberKey = "tenant:$TenantId`:graph:$memberId"
            if (-not ($result.Nodes.Key -contains $memberKey)) {
                $memberName = if ($memberDisplayName) { $memberDisplayName } else { $memberId }
                $result.Nodes.Add(
                    (New-AtlasNode -TenantId $TenantId -Id $memberId -Kind $memberKind -DisplayName $memberName -Status 'partial' -Source @{
                        provider = 'microsoftGraph'
                        apiVersion = 'v1.0'
                        odataType = $odataType
                        resourcePath = "/directoryObjects/$memberId"
                        collector = 'groupMemberships'
                    })
                )
            }

            $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'groupMemberships' -Endpoint $membersEndpoint -SourceObjectId "$memberId|$($group.id)" -Fields @{
                memberId = $memberId
                groupId = $group.id
                assignment = 'direct'
            }
            $result.Evidence.Add($evidence)
            $result.Edges.Add(
                (New-AtlasEdge -TenantId $TenantId -From $memberKey -To $groupNode.Key -Relationship 'memberOf' -State @{
                    assignment = 'direct'
                } -EvidenceIds @($evidence.Key) -Source @{
                    collector = 'groupMemberships'
                })
            )
        }

        $ownersEndpoint = "/v1.0/groups/$($group.id)/owners?`$select=id,displayName"
        try {
            $ownersResponse = Invoke-AtlasGraphRequest -Uri $ownersEndpoint
        }
        catch {
            $result.Status = 'partial'
            $result.Warnings.Add("Owners could not be collected for group '$($group.displayName)': $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
            continue
        }

        foreach ($owner in $ownersResponse.Items) {
            $ownerId = Get-AtlasResponseProperty -InputObject $owner -Name 'id'
            if (-not $ownerId) {
                continue
            }

            $odataType = Get-AtlasResponseProperty -InputObject $owner -Name '@odata.type'
            $ownerDisplayName = Get-AtlasResponseProperty -InputObject $owner -Name 'displayName'
            $ownerKind = switch ($odataType) {
                '#microsoft.graph.user' { 'user' }
                '#microsoft.graph.group' { 'group' }
                '#microsoft.graph.servicePrincipal' { 'servicePrincipal' }
                default { 'directoryObject' }
            }

            $ownerKey = "tenant:$TenantId`:graph:$ownerId"
            if (-not ($result.Nodes.Key -contains $ownerKey)) {
                $ownerName = if ($ownerDisplayName) { $ownerDisplayName } else { $ownerId }
                $result.Nodes.Add(
                    (New-AtlasNode -TenantId $TenantId -Id $ownerId -Kind $ownerKind -DisplayName $ownerName -Status 'partial' -Source @{
                        provider = 'microsoftGraph'
                        apiVersion = 'v1.0'
                        odataType = $odataType
                        resourcePath = "/directoryObjects/$ownerId"
                        collector = 'groupOwners'
                    })
                )
            }

            $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'groupOwners' -Endpoint $ownersEndpoint -SourceObjectId "$($group.id)|owner|$ownerId" -Fields @{
                groupId = $group.id
                ownerId = $ownerId
            }
            $result.Evidence.Add($evidence)
            $result.Edges.Add(
                (New-AtlasEdge -TenantId $TenantId -From $groupNode.Key -To $ownerKey -Relationship 'ownedBy' -State @{
                    ownerId = $ownerId
                } -EvidenceIds @($evidence.Key) -Source @{
                    collector = 'groupOwners'
                })
            )
        }
    }

    $result.Metrics = @{
        groupCount = $response.Items.Count
        requestCount = $response.Metrics.requestCount
        retryCount = $response.Metrics.retryCount
    }
    return $result
}
