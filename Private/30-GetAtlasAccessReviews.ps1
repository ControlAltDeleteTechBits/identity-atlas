function Get-AtlasGraphIdsFromQuery {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string] $Query
    )

    if ([string]::IsNullOrWhiteSpace($Query)) {
        return @()
    }

    return @(
        [regex]::Matches($Query, '(?i)(?:groups|users|servicePrincipals|applications)/([0-9a-f-]{8,})') |
            ForEach-Object { $_.Groups[1].Value } |
            Sort-Object -Unique
    )
}

function Get-AtlasAccessPackageIdsFromQuery {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string] $Query
    )

    if ([string]::IsNullOrWhiteSpace($Query)) {
        return @()
    }

    return @(
        [regex]::Matches($Query, '(?i)accessPackage(?:Id|/id)?\s+(?:eq\s+)?[''"]?([0-9a-f-]{8,})') |
            ForEach-Object { $_.Groups[1].Value } |
            Sort-Object -Unique
    )
}

function Get-AtlasAccessReview {
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
    foreach ($node in $KnownNode) {
        $keyById[$node.Id] = $node.Key
        foreach ($propertyName in @('accessPackageId', 'assignmentPolicyId', 'catalogId')) {
            if ($node.Properties.ContainsKey($propertyName) -and $node.Properties[$propertyName]) {
                $keyById[$node.Properties[$propertyName]] = $node.Key
            }
        }
    }

    $definitionsEndpoint = '/v1.0/identityGovernance/accessReviews/definitions'
    $definitionResponse = Invoke-AtlasGraphRequest -Uri $definitionsEndpoint
    $requestCount = $definitionResponse.Metrics.requestCount
    $retryCount = $definitionResponse.Metrics.retryCount
    $instanceCount = 0
    $decisionCount = 0
    $coveredTargetCount = 0
    $reviewerEdgeCount = 0

    foreach ($definition in $definitionResponse.Items) {
        $scope = Get-AtlasResponseProperty -InputObject $definition -Name 'scope'
        $instanceEnumerationScope = Get-AtlasResponseProperty -InputObject $definition -Name 'instanceEnumerationScope'
        $scopeQuery = Get-AtlasResponseProperty -InputObject $scope -Name 'query'
        $enumerationQuery = Get-AtlasResponseProperty -InputObject $instanceEnumerationScope -Name 'query'
        $definitionNode = New-AtlasNode -TenantId $TenantId -Id "accessReviewDefinition:$($definition.id)" -Kind 'accessReviewDefinition' -DisplayName $definition.displayName -Properties @{
            accessReviewDefinitionId = $definition.id
            descriptionForAdmins = Get-AtlasResponseProperty -InputObject $definition -Name 'descriptionForAdmins'
            descriptionForReviewers = Get-AtlasResponseProperty -InputObject $definition -Name 'descriptionForReviewers'
            status = Get-AtlasResponseProperty -InputObject $definition -Name 'status'
            createdDateTime = Get-AtlasResponseProperty -InputObject $definition -Name 'createdDateTime'
            lastModifiedDateTime = Get-AtlasResponseProperty -InputObject $definition -Name 'lastModifiedDateTime'
            scope = $scope
            instanceEnumerationScope = $instanceEnumerationScope
            settings = Get-AtlasResponseProperty -InputObject $definition -Name 'settings'
            reviewers = @(Get-AtlasResponseProperty -InputObject $definition -Name 'reviewers')
            fallbackReviewers = @(Get-AtlasResponseProperty -InputObject $definition -Name 'fallbackReviewers')
        } -Source @{
            provider = 'microsoftGraph'
            apiVersion = 'v1.0'
            odataType = '#microsoft.graph.accessReviewScheduleDefinition'
            resourcePath = "/identityGovernance/accessReviews/definitions/$($definition.id)"
            collector = 'accessReviews'
        } -Tags @('governance', 'accessReview')
        $result.Nodes.Add($definitionNode)

        $targetId = @(
            Get-AtlasGraphIdsFromQuery -Query $scopeQuery
            Get-AtlasGraphIdsFromQuery -Query $enumerationQuery
            Get-AtlasAccessPackageIdsFromQuery -Query $scopeQuery
            Get-AtlasAccessPackageIdsFromQuery -Query $enumerationQuery
        ) | Sort-Object -Unique
        foreach ($id in $targetId) {
            if (-not $keyById.ContainsKey($id)) { continue }
            $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'accessReviews' -Endpoint $definitionsEndpoint -SourceObjectId "$($definition.id)|target|$id" -Fields @{
                accessReviewDefinitionId = $definition.id
                targetId = $id
                scopeQuery = $scopeQuery
                instanceEnumerationQuery = $enumerationQuery
            }
            $result.Evidence.Add($evidence)
            $result.Edges.Add(
                (New-AtlasEdge -TenantId $TenantId -From $keyById[$id] -To $definitionNode.Key -Relationship 'coveredByAccessReview' -State @{
                    reviewStatus = Get-AtlasResponseProperty -InputObject $definition -Name 'status'
                } -EvidenceIds @($evidence.Key) -Source @{ collector = 'accessReviews' })
            )
            $coveredTargetCount++
        }

        $reviewerSets = @(
            @{ Items = @(Get-AtlasResponseProperty -InputObject $definition -Name 'reviewers'); Type = 'primary' }
            @{ Items = @(Get-AtlasResponseProperty -InputObject $definition -Name 'fallbackReviewers'); Type = 'fallback' }
        )
        foreach ($reviewerSet in $reviewerSets) {
            foreach ($reviewerScope in $reviewerSet.Items) {
                if ($null -eq $reviewerScope) { continue }
                $query = Get-AtlasResponseProperty -InputObject $reviewerScope -Name 'query'
                $reviewerId = @(Get-AtlasGraphIdsFromQuery -Query $query)
                if ($reviewerId.Count -eq 0) {
                    $scopeId = "accessReviewReviewerScope:$(Get-AtlasStableId -InputString "$($definition.id)|$($reviewerSet.Type)|$query")"
                    $scopeKey = "tenant:$TenantId`:graph:$scopeId"
                    if (-not $addedNode.ContainsKey($scopeKey)) {
                        $scopeName = if ($query) { $query } else { 'Self review' }
                        $scopeNode = New-AtlasNode -TenantId $TenantId -Id $scopeId -Kind 'accessReviewReviewerScope' -DisplayName $scopeName -Properties @{
                            query = $query
                            queryRoot = Get-AtlasResponseProperty -InputObject $reviewerScope -Name 'queryRoot'
                            queryType = Get-AtlasResponseProperty -InputObject $reviewerScope -Name 'queryType'
                            reviewerType = $reviewerSet.Type
                        } -Source @{
                            provider = 'microsoftGraph'
                            apiVersion = 'v1.0'
                            odataType = '#microsoft.graph.accessReviewReviewerScope'
                            resourcePath = "/identityGovernance/accessReviews/definitions/$($definition.id)"
                            collector = 'accessReviews'
                        } -Tags @('governance', 'reviewerScope')
                        $result.Nodes.Add($scopeNode)
                        $addedNode[$scopeKey] = $true
                    }
                    $reviewerId = @($scopeId)
                    $keyById[$scopeId] = $scopeKey
                }

                foreach ($id in $reviewerId) {
                    if (-not $keyById.ContainsKey($id)) { continue }
                    $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'accessReviews' -Endpoint $definitionsEndpoint -SourceObjectId "$($definition.id)|reviewer|$id|$($reviewerSet.Type)" -Fields @{
                        accessReviewDefinitionId = $definition.id
                        reviewerId = $id
                        reviewerType = $reviewerSet.Type
                        query = $query
                    }
                    $result.Evidence.Add($evidence)
                    $result.Edges.Add(
                        (New-AtlasEdge -TenantId $TenantId -From $keyById[$id] -To $definitionNode.Key -Relationship 'reviewsAccess' -State @{
                            reviewerType = $reviewerSet.Type
                        } -EvidenceIds @($evidence.Key) -Source @{ collector = 'accessReviews' })
                    )
                    $reviewerEdgeCount++
                }
            }
        }

        $instancesEndpoint = "/v1.0/identityGovernance/accessReviews/definitions/$($definition.id)/instances"
        try {
            $instanceResponse = Invoke-AtlasGraphRequest -Uri $instancesEndpoint
            $requestCount += $instanceResponse.Metrics.requestCount
            $retryCount += $instanceResponse.Metrics.retryCount
        }
        catch {
            $result.Status = 'partial'
            $result.Warnings.Add("Instances could not be collected for access review '$($definition.displayName)': $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
            continue
        }

        foreach ($instance in $instanceResponse.Items) {
            $instanceNode = New-AtlasNode -TenantId $TenantId -Id "accessReviewInstance:$($instance.id)" -Kind 'accessReviewInstance' -DisplayName "$($definition.displayName) instance" -Properties @{
                accessReviewInstanceId = $instance.id
                definitionId = $definition.id
                status = Get-AtlasResponseProperty -InputObject $instance -Name 'status'
                startDateTime = Get-AtlasResponseProperty -InputObject $instance -Name 'startDateTime'
                endDateTime = Get-AtlasResponseProperty -InputObject $instance -Name 'endDateTime'
                reviewedEntity = Get-AtlasResponseProperty -InputObject $instance -Name 'reviewedEntity'
            } -Source @{
                provider = 'microsoftGraph'
                apiVersion = 'v1.0'
                odataType = '#microsoft.graph.accessReviewInstance'
                resourcePath = "/identityGovernance/accessReviews/definitions/$($definition.id)/instances/$($instance.id)"
                collector = 'accessReviews'
            } -Tags @('governance', 'accessReviewInstance')
            $result.Nodes.Add($instanceNode)

            $instanceEvidence = New-AtlasEvidence -TenantId $TenantId -Collector 'accessReviews' -Endpoint $instancesEndpoint -SourceObjectId $instance.id -Fields @{
                accessReviewDefinitionId = $definition.id
                accessReviewInstanceId = $instance.id
                status = Get-AtlasResponseProperty -InputObject $instance -Name 'status'
                startDateTime = Get-AtlasResponseProperty -InputObject $instance -Name 'startDateTime'
                endDateTime = Get-AtlasResponseProperty -InputObject $instance -Name 'endDateTime'
            }
            $result.Evidence.Add($instanceEvidence)
            $result.Edges.Add(
                (New-AtlasEdge -TenantId $TenantId -From $definitionNode.Key -To $instanceNode.Key -Relationship 'hasAccessReviewInstance' -EvidenceIds @($instanceEvidence.Key) -Source @{ collector = 'accessReviews' })
            )
            $instanceCount++

            $decisionsEndpoint = "/v1.0/identityGovernance/accessReviews/definitions/$($definition.id)/instances/$($instance.id)/decisions"
            try {
                $decisionResponse = Invoke-AtlasGraphRequest -Uri $decisionsEndpoint
                $requestCount += $decisionResponse.Metrics.requestCount
                $retryCount += $decisionResponse.Metrics.retryCount
            }
            catch {
                $result.Status = 'partial'
                $result.Warnings.Add("Decisions could not be collected for an instance of access review '$($definition.displayName)': $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
                continue
            }

            foreach ($decision in $decisionResponse.Items) {
                $principal = Get-AtlasResponseProperty -InputObject $decision -Name 'principal'
                $resource = Get-AtlasResponseProperty -InputObject $decision -Name 'resource'
                $principalId = Get-AtlasResponseProperty -InputObject $principal -Name 'id'
                $resourceId = Get-AtlasResponseProperty -InputObject $resource -Name 'id'
                if (-not $principalId) { continue }

                if ($keyById.ContainsKey($principalId)) {
                    $principalKey = $keyById[$principalId]
                }
                else {
                    $principalKey = "tenant:$TenantId`:graph:$principalId"
                    if (-not $addedNode.ContainsKey($principalKey)) {
                        $principalName = Get-AtlasResponseProperty -InputObject $principal -Name 'displayName'
                        if (-not $principalName) { $principalName = $principalId }
                        $principalNode = New-AtlasNode -TenantId $TenantId -Id $principalId -Kind 'directoryObject' -DisplayName $principalName -Status 'partial' -Source @{
                            provider = 'microsoftGraph'
                            apiVersion = 'v1.0'
                            resourcePath = Get-AtlasResponseProperty -InputObject $decision -Name 'principalLink'
                            collector = 'accessReviews'
                        }
                        $result.Nodes.Add($principalNode)
                        $addedNode[$principalKey] = $true
                    }
                    $keyById[$principalId] = $principalKey
                }

                $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'accessReviews' -Endpoint $decisionsEndpoint -SourceObjectId $decision.id -Fields @{
                    decisionId = $decision.id
                    principalId = $principalId
                    resourceId = $resourceId
                    decision = Get-AtlasResponseProperty -InputObject $decision -Name 'decision'
                    recommendation = Get-AtlasResponseProperty -InputObject $decision -Name 'recommendation'
                    justification = Get-AtlasResponseProperty -InputObject $decision -Name 'justification'
                    reviewedBy = Get-AtlasResponseProperty -InputObject $decision -Name 'reviewedBy'
                    reviewedDateTime = Get-AtlasResponseProperty -InputObject $decision -Name 'reviewedDateTime'
                    applyResult = Get-AtlasResponseProperty -InputObject $decision -Name 'applyResult'
                    appliedDateTime = Get-AtlasResponseProperty -InputObject $decision -Name 'appliedDateTime'
                }
                $result.Evidence.Add($evidence)
                $result.Edges.Add(
                    (New-AtlasEdge -TenantId $TenantId -From $principalKey -To $instanceNode.Key -Relationship 'reviewedInAccessReview' -State @{
                        resourceId = $resourceId
                        decision = Get-AtlasResponseProperty -InputObject $decision -Name 'decision'
                        recommendation = Get-AtlasResponseProperty -InputObject $decision -Name 'recommendation'
                        reviewedDateTime = Get-AtlasResponseProperty -InputObject $decision -Name 'reviewedDateTime'
                        applyResult = Get-AtlasResponseProperty -InputObject $decision -Name 'applyResult'
                    } -EvidenceIds @($evidence.Key) -Source @{ collector = 'accessReviews' })
                )
                if ($resourceId -and $keyById.ContainsKey($resourceId)) {
                    $result.Edges.Add(
                        (New-AtlasEdge -TenantId $TenantId -From $keyById[$resourceId] -To $instanceNode.Key -Relationship 'resourceReviewedInAccessReview' -State @{
                            principalId = $principalId
                            decision = Get-AtlasResponseProperty -InputObject $decision -Name 'decision'
                        } -EvidenceIds @($evidence.Key) -Source @{ collector = 'accessReviews' })
                    )
                }
                $decisionCount++
            }
        }
    }

    $result.Metrics = @{
        definitionCount = $definitionResponse.Items.Count
        instanceCount = $instanceCount
        decisionCount = $decisionCount
        coveredTargetCount = $coveredTargetCount
        reviewerEdgeCount = $reviewerEdgeCount
        requestCount = $requestCount
        retryCount = $retryCount
    }
    return $result
}
