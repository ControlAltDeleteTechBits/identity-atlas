function Get-AtlasAdministrativeUnit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TenantId,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AtlasNode[]] $KnownNode,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AtlasEdge[]] $KnownEdge
    )

    $result = [AtlasCollectionResult]::new()
    $keyById = @{}
    $nodeByKey = @{}
    foreach ($node in $KnownNode) {
        $keyById[$node.Id] = $node.Key
        $nodeByKey[$node.Key] = $node
    }

    $endpoint = '/v1.0/directory/administrativeUnits?$select=id,displayName,description,membershipType,membershipRule,membershipRuleProcessingState,isMemberManagementRestricted,visibility'
    $response = Invoke-AtlasGraphRequest -Uri $endpoint
    $memberRequestCount = 0
    $memberRetryCount = 0
    $memberCount = 0
    $scopedAssignmentCount = 0

    foreach ($unit in $response.Items) {
        $unitNode = New-AtlasNode -TenantId $TenantId -Id $unit.id -Kind 'administrativeUnit' -DisplayName $unit.displayName -Properties @{
            description = Get-AtlasResponseProperty -InputObject $unit -Name 'description'
            membershipType = Get-AtlasResponseProperty -InputObject $unit -Name 'membershipType'
            membershipRule = Get-AtlasResponseProperty -InputObject $unit -Name 'membershipRule'
            membershipRuleProcessingState = Get-AtlasResponseProperty -InputObject $unit -Name 'membershipRuleProcessingState'
            isMemberManagementRestricted = Get-AtlasResponseProperty -InputObject $unit -Name 'isMemberManagementRestricted'
            visibility = Get-AtlasResponseProperty -InputObject $unit -Name 'visibility'
        } -Source @{
            provider = 'microsoftGraph'
            apiVersion = 'v1.0'
            odataType = '#microsoft.graph.administrativeUnit'
            resourcePath = "/directory/administrativeUnits/$($unit.id)"
            collector = 'administrativeUnits'
        } -Tags @('governance', 'delegatedAdministration')
        $result.Nodes.Add($unitNode)

        $membersEndpoint = "/v1.0/directory/administrativeUnits/$($unit.id)/members?`$select=id,displayName,userPrincipalName,deviceId"
        try {
            $membersResponse = Invoke-AtlasGraphRequest -Uri $membersEndpoint
            $memberRequestCount += $membersResponse.Metrics.requestCount
            $memberRetryCount += $membersResponse.Metrics.retryCount
        }
        catch {
            $result.Status = 'partial'
            $result.Warnings.Add("Members could not be collected for Administrative Unit '$($unit.displayName)': $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
            continue
        }

        foreach ($member in $membersResponse.Items) {
            $memberId = Get-AtlasResponseProperty -InputObject $member -Name 'id'
            if (-not $memberId) { continue }
            if ($keyById.ContainsKey($memberId)) {
                $memberKey = $keyById[$memberId]
            }
            else {
                $odataType = Get-AtlasResponseProperty -InputObject $member -Name '@odata.type'
                $memberKind = switch ($odataType) {
                    '#microsoft.graph.user' { 'user' }
                    '#microsoft.graph.group' { 'group' }
                    '#microsoft.graph.device' { 'device' }
                    default { 'directoryObject' }
                }
                $memberName = Get-AtlasResponseProperty -InputObject $member -Name 'displayName'
                if (-not $memberName) { $memberName = $memberId }
                $memberNode = New-AtlasNode -TenantId $TenantId -Id $memberId -Kind $memberKind -DisplayName $memberName -Status 'partial' -Source @{
                    provider = 'microsoftGraph'
                    apiVersion = 'v1.0'
                    odataType = $odataType
                    resourcePath = "/directoryObjects/$memberId"
                    collector = 'administrativeUnits'
                }
                $result.Nodes.Add($memberNode)
                $keyById[$memberId] = $memberNode.Key
                $nodeByKey[$memberNode.Key] = $memberNode
                $memberKey = $memberNode.Key
            }

            $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'administrativeUnits' -Endpoint $membersEndpoint -SourceObjectId "$memberId|$($unit.id)" -Fields @{
                memberId = $memberId
                administrativeUnitId = $unit.id
            }
            $result.Evidence.Add($evidence)
            $result.Edges.Add(
                (New-AtlasEdge -TenantId $TenantId -From $memberKey -To $unitNode.Key -Relationship 'memberOfAdministrativeUnit' -State @{
                    membershipType = Get-AtlasResponseProperty -InputObject $unit -Name 'membershipType'
                } -EvidenceIds @($evidence.Key) -Source @{ collector = 'administrativeUnits' })
            )
            $memberCount++
        }

        $expectedScope = "/administrativeUnits/$($unit.id)"
        foreach ($assignmentEdge in $KnownEdge) {
            $directoryScopeId = Get-AtlasResponseProperty -InputObject $assignmentEdge.State -Name 'directoryScopeId'
            if ($directoryScopeId -ne $expectedScope -or $assignmentEdge.Relationship -notin @('assignedRole', 'eligibleRole')) {
                continue
            }
            $roleNode = $nodeByKey[$assignmentEdge.To]
            $principalNode = $nodeByKey[$assignmentEdge.From]
            $roleName = if ($roleNode) { $roleNode.DisplayName } else { $assignmentEdge.To }

            $result.Edges.Add(
                (New-AtlasEdge -TenantId $TenantId -From $assignmentEdge.To -To $unitNode.Key -Relationship 'scopedToAdministrativeUnit' -State @{
                    assignmentId = Get-AtlasResponseProperty -InputObject $assignmentEdge.State -Name 'assignmentId'
                    activation = Get-AtlasResponseProperty -InputObject $assignmentEdge.State -Name 'activation'
                    principalId = if ($principalNode) { $principalNode.Id } else { $assignmentEdge.From }
                } -EvidenceIds @($assignmentEdge.EvidenceIds) -Source @{ collector = 'administrativeUnits'; derivedFrom = $assignmentEdge.Key })
            )
            $result.Edges.Add(
                (New-AtlasEdge -TenantId $TenantId -From $assignmentEdge.From -To $unitNode.Key -Relationship 'administersAdministrativeUnit' -State @{
                    roleDefinitionId = if ($roleNode) { $roleNode.Id } else { $null }
                    roleDisplayName = $roleName
                    activation = Get-AtlasResponseProperty -InputObject $assignmentEdge.State -Name 'activation'
                } -EvidenceIds @($assignmentEdge.EvidenceIds) -Source @{ collector = 'administrativeUnits'; derivedFrom = $assignmentEdge.Key })
            )
            $scopedAssignmentCount++
        }
    }

    $result.Metrics = @{
        administrativeUnitCount = $response.Items.Count
        memberCount = $memberCount
        scopedRoleAssignmentCount = $scopedAssignmentCount
        requestCount = $response.Metrics.requestCount + $memberRequestCount
        retryCount = $response.Metrics.retryCount + $memberRetryCount
    }
    return $result
}

function Get-AtlasPrivilegedGroupAssignment {
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
    $addedNode = @{}
    $groupNode = @($KnownNode | Where-Object Kind -eq 'group')
    foreach ($node in $KnownNode) {
        $keyById[$node.Id] = $node.Key
    }

    $requestCount = 0
    $retryCount = 0
    $failedGroup = @{}
    $failedRequestCount = 0
    $activeCount = 0
    $eligibleCount = 0

    foreach ($group in $groupNode) {
        $filter = [uri]::EscapeDataString("groupId eq '$($group.Id)'")
        $assignmentEndpoint = "/v1.0/identityGovernance/privilegedAccess/group/assignmentScheduleInstances?`$filter=$filter&`$select=id,groupId,principalId,accessId,memberType,assignmentType,startDateTime,endDateTime"
        $eligibilityEndpoint = "/v1.0/identityGovernance/privilegedAccess/group/eligibilityScheduleInstances?`$filter=$filter&`$select=id,groupId,principalId,accessId,memberType,startDateTime,endDateTime"

        $scheduleSets = @()
        foreach ($request in @(
            @{ Activation = 'active'; Endpoint = $assignmentEndpoint }
            @{ Activation = 'eligible'; Endpoint = $eligibilityEndpoint }
        )) {
            try {
                $scheduleResponse = Invoke-AtlasGraphRequest -Uri $request.Endpoint
                $requestCount += $scheduleResponse.Metrics.requestCount
                $retryCount += $scheduleResponse.Metrics.retryCount
                $scheduleSets += @{
                    Items = @($scheduleResponse.Items)
                    Activation = $request.Activation
                    Endpoint = $request.Endpoint
                }
            }
            catch {
                $failedGroup[$group.Id] = $group.DisplayName
                $failedRequestCount++
            }
        }
        foreach ($scheduleSet in $scheduleSets) {
            foreach ($schedule in $scheduleSet.Items) {
                $principalId = Get-AtlasResponseProperty -InputObject $schedule -Name 'principalId'
                if (-not $principalId) { continue }
                if ($keyById.ContainsKey($principalId)) {
                    $principalKey = $keyById[$principalId]
                }
                else {
                    $principalKey = "tenant:$TenantId`:graph:$principalId"
                    if (-not $addedNode.ContainsKey($principalKey)) {
                        $principalNode = New-AtlasNode -TenantId $TenantId -Id $principalId -Kind 'directoryObject' -DisplayName $principalId -Status 'unresolved' -Source @{
                            provider = 'microsoftGraph'
                            apiVersion = 'v1.0'
                            resourcePath = "/directoryObjects/$principalId"
                            collector = 'pimGroups'
                        }
                        $result.Nodes.Add($principalNode)
                        $addedNode[$principalKey] = $true
                    }
                }

                $accessId = [string] (Get-AtlasResponseProperty -InputObject $schedule -Name 'accessId')
                $relationship = if ($scheduleSet.Activation -eq 'eligible') {
                    if ($accessId -eq 'owner') { 'pimEligibleOwner' } else { 'pimEligibleMember' }
                }
                else {
                    if ($accessId -eq 'owner') { 'pimActiveOwner' } else { 'pimActiveMember' }
                }
                $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'pimGroups' -Endpoint $scheduleSet.Endpoint -SourceObjectId $schedule.id -Fields @{
                    groupId = $group.Id
                    principalId = $principalId
                    accessId = $accessId
                    activation = $scheduleSet.Activation
                    memberType = Get-AtlasResponseProperty -InputObject $schedule -Name 'memberType'
                    assignmentType = Get-AtlasResponseProperty -InputObject $schedule -Name 'assignmentType'
                    startDateTime = Get-AtlasResponseProperty -InputObject $schedule -Name 'startDateTime'
                    endDateTime = Get-AtlasResponseProperty -InputObject $schedule -Name 'endDateTime'
                }
                $result.Evidence.Add($evidence)
                $result.Edges.Add(
                    (New-AtlasEdge -TenantId $TenantId -From $principalKey -To $group.Key -Relationship $relationship -State @{
                        activation = $scheduleSet.Activation
                        accessId = $accessId
                        memberType = Get-AtlasResponseProperty -InputObject $schedule -Name 'memberType'
                        assignmentType = Get-AtlasResponseProperty -InputObject $schedule -Name 'assignmentType'
                        startDateTime = Get-AtlasResponseProperty -InputObject $schedule -Name 'startDateTime'
                        endDateTime = Get-AtlasResponseProperty -InputObject $schedule -Name 'endDateTime'
                    } -EvidenceIds @($evidence.Key) -Source @{ collector = 'pimGroups' })
                )
                if ($scheduleSet.Activation -eq 'eligible') { $eligibleCount++ } else { $activeCount++ }
            }
        }
    }

    if ($failedGroup.Count -gt 0) {
        $result.Status = 'partial'
        $sample = @($failedGroup.Values | Select-Object -First 5) -join ', '
        $result.Warnings.Add("$failedRequestCount PIM for Groups request(s) failed across $($failedGroup.Count) group(s). First affected group(s): $sample. Successful active or eligible results were retained. The signed-in account may need a supported Microsoft Entra role in addition to the delegated Graph permissions.")
    }
    $result.Metrics = @{
        evaluatedGroupCount = $groupNode.Count
        failedGroupCount = $failedGroup.Count
        failedRequestCount = $failedRequestCount
        activeAssignmentCount = $activeCount
        eligibleAssignmentCount = $eligibleCount
        requestCount = $requestCount
        retryCount = $retryCount
    }
    return $result
}
