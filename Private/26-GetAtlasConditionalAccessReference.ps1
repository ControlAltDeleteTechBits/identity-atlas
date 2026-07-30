function Get-AtlasConditionalAccessReference {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TenantId,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AtlasNode[]] $KnownNode
    )

    $result = [AtlasCollectionResult]::new()
    $policyKeyById = @{}
    foreach ($node in $KnownNode | Where-Object Kind -eq 'conditionalAccessPolicy') {
        $policyKeyById[$node.Id] = $node.Key
    }

    $namedLocationsEndpoint = '/v1.0/identity/conditionalAccess/namedLocations'
    $authStrengthEndpoint = '/v1.0/policies/authenticationStrengthPolicies'
    $policiesEndpoint = '/v1.0/identity/conditionalAccess/policies'

    try {
        $namedLocationResponse = Invoke-AtlasGraphRequest -Uri $namedLocationsEndpoint
    }
    catch {
        $result.Status = 'partial'
        $result.Warnings.Add("Conditional Access named locations could not be collected: $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
        $namedLocationResponse = [pscustomobject] @{
            Items = @()
            Metrics = @{ requestCount = 0; retryCount = 0 }
        }
    }

    try {
        $authStrengthResponse = Invoke-AtlasGraphRequest -Uri $authStrengthEndpoint
    }
    catch {
        $result.Status = 'partial'
        $result.Warnings.Add("Authentication strengths could not be collected: $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
        $authStrengthResponse = [pscustomobject] @{
            Items = @()
            Metrics = @{ requestCount = 0; retryCount = 0 }
        }
    }

    try {
        $policyResponse = Invoke-AtlasGraphRequest -Uri $policiesEndpoint
    }
    catch {
        $result.Status = 'partial'
        $result.Warnings.Add("Conditional Access policy references could not be collected: $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
        $policyResponse = [pscustomobject] @{
            Items = @()
            Metrics = @{ requestCount = 0; retryCount = 0 }
        }
    }

    $namedLocationKeyById = @{}
    foreach ($location in $namedLocationResponse.Items) {
        $locationId = Get-AtlasResponseProperty -InputObject $location -Name 'id'
        if (-not $locationId) {
            continue
        }
        $displayName = Get-AtlasResponseProperty -InputObject $location -Name 'displayName'
        if (-not $displayName) { $displayName = $locationId }
        $odataType = Get-AtlasResponseProperty -InputObject $location -Name '@odata.type'
        $node = New-AtlasNode -TenantId $TenantId -Id $locationId -Kind 'namedLocation' -DisplayName $displayName -Properties @{
            odataType = $odataType
            createdDateTime = Get-AtlasResponseProperty -InputObject $location -Name 'createdDateTime'
            modifiedDateTime = Get-AtlasResponseProperty -InputObject $location -Name 'modifiedDateTime'
            isTrusted = Get-AtlasResponseProperty -InputObject $location -Name 'isTrusted'
        } -Source @{
            provider = 'microsoftGraph'
            apiVersion = 'v1.0'
            odataType = $odataType
            resourcePath = "/identity/conditionalAccess/namedLocations/$locationId"
            collector = 'conditionalAccessReferences'
        }
        $result.Nodes.Add($node)
        $namedLocationKeyById[$locationId] = $node.Key
    }

    $authStrengthKeyById = @{}
    foreach ($strength in $authStrengthResponse.Items) {
        $strengthId = Get-AtlasResponseProperty -InputObject $strength -Name 'id'
        if (-not $strengthId) {
            continue
        }
        $displayName = Get-AtlasResponseProperty -InputObject $strength -Name 'displayName'
        if (-not $displayName) { $displayName = $strengthId }
        $node = New-AtlasNode -TenantId $TenantId -Id $strengthId -Kind 'authenticationStrength' -DisplayName $displayName -Properties @{
            description = Get-AtlasResponseProperty -InputObject $strength -Name 'description'
            policyType = Get-AtlasResponseProperty -InputObject $strength -Name 'policyType'
            requirementsSatisfied = Get-AtlasResponseProperty -InputObject $strength -Name 'requirementsSatisfied'
            allowedCombinations = @(Get-AtlasResponseProperty -InputObject $strength -Name 'allowedCombinations')
        } -Source @{
            provider = 'microsoftGraph'
            apiVersion = 'v1.0'
            odataType = '#microsoft.graph.authenticationStrengthPolicy'
            resourcePath = "/policies/authenticationStrengthPolicies/$strengthId"
            collector = 'conditionalAccessReferences'
        }
        $result.Nodes.Add($node)
        $authStrengthKeyById[$strengthId] = $node.Key
    }

    foreach ($policy in $policyResponse.Items) {
        $policyId = Get-AtlasResponseProperty -InputObject $policy -Name 'id'
        if (-not $policyId -or -not $policyKeyById.ContainsKey($policyId)) {
            continue
        }
        $policyKey = $policyKeyById[$policyId]
        $conditions = Get-AtlasResponseProperty -InputObject $policy -Name 'conditions'
        $locations = Get-AtlasResponseProperty -InputObject $conditions -Name 'locations'
        $grantControls = Get-AtlasResponseProperty -InputObject $policy -Name 'grantControls'
        $authenticationStrength = Get-AtlasResponseProperty -InputObject $grantControls -Name 'authenticationStrength'
        $authenticationStrengthId = Get-AtlasResponseProperty -InputObject $authenticationStrength -Name 'id'

        foreach ($locationSet in @(
            @{ Values = @(Get-AtlasConditionalAccessCollection -Object $locations -Name 'includeLocations'); Relationship = 'conditionalAccessIncludesLocation'; Assignment = 'include' }
            @{ Values = @(Get-AtlasConditionalAccessCollection -Object $locations -Name 'excludeLocations'); Relationship = 'conditionalAccessExcludesLocation'; Assignment = 'exclude' }
        )) {
            foreach ($locationId in $locationSet.Values) {
                if (-not $locationId -or $locationId -eq 'All' -or -not $namedLocationKeyById.ContainsKey($locationId)) {
                    continue
                }
                $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'conditionalAccessReferences' -Endpoint $policiesEndpoint -SourceObjectId "$policyId|$($locationSet.Assignment)|location|$locationId" -Fields @{
                    policyId = $policyId
                    locationId = $locationId
                    assignment = $locationSet.Assignment
                }
                $result.Evidence.Add($evidence)
                $result.Edges.Add(
                    (New-AtlasEdge -TenantId $TenantId -From $policyKey -To $namedLocationKeyById[$locationId] -Relationship $locationSet.Relationship -State @{
                        assignment = $locationSet.Assignment
                    } -EvidenceIds @($evidence.Key) -Source @{
                        collector = 'conditionalAccessReferences'
                    })
                )
            }
        }

        if ($authenticationStrengthId -and $authStrengthKeyById.ContainsKey($authenticationStrengthId)) {
            $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'conditionalAccessReferences' -Endpoint $policiesEndpoint -SourceObjectId "$policyId|authenticationStrength|$authenticationStrengthId" -Fields @{
                policyId = $policyId
                authenticationStrengthId = $authenticationStrengthId
            }
            $result.Evidence.Add($evidence)
            $result.Edges.Add(
                (New-AtlasEdge -TenantId $TenantId -From $policyKey -To $authStrengthKeyById[$authenticationStrengthId] -Relationship 'requiresAuthenticationStrength' -State @{
                    authenticationStrengthId = $authenticationStrengthId
                } -EvidenceIds @($evidence.Key) -Source @{
                    collector = 'conditionalAccessReferences'
                })
            )
        }
    }

    $result.Metrics = @{
        namedLocationCount = $namedLocationResponse.Items.Count
        authenticationStrengthCount = $authStrengthResponse.Items.Count
        referenceEdgeCount = $result.Edges.Count
        requestCount = $namedLocationResponse.Metrics.requestCount + $authStrengthResponse.Metrics.requestCount + $policyResponse.Metrics.requestCount
        retryCount = $namedLocationResponse.Metrics.retryCount + $authStrengthResponse.Metrics.retryCount + $policyResponse.Metrics.retryCount
    }
    return $result
}
