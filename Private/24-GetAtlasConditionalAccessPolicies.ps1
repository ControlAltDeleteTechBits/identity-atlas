function Get-AtlasConditionalAccessCollection {
    [CmdletBinding()]
    param(
        [object] $Object,

        [Parameter(Mandatory)]
        [string] $Name
    )

    if ($null -eq $Object) {
        return @()
    }

    $value = Get-AtlasResponseProperty -InputObject $Object -Name $Name
    if ($null -eq $value) {
        return @()
    }

    return @($value)
}

function New-AtlasConditionalAccessScopeNode {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Creates an in-memory model object and does not change external state.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TenantId,

        [Parameter(Mandatory)]
        [string] $ScopeId,

        [Parameter(Mandatory)]
        [string] $DisplayName,

        [Parameter(Mandatory)]
        [string] $SubjectKind
    )

    return New-AtlasNode -TenantId $TenantId -Id "conditionalAccessScope:$ScopeId" -Kind 'conditionalAccessScope' -DisplayName $DisplayName -Properties @{
        subjectKind = $SubjectKind
    } -Source @{
        provider = 'microsoftGraph'
        apiVersion = 'v1.0'
        odataType = '#microsoft.graph.conditionalAccessScope'
        resourcePath = "/identity/conditionalAccess/policies"
        collector = 'conditionalAccess'
    } -Tags @('synthetic')
}

function Get-AtlasConditionalAccessPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TenantId,

        [Parameter(Mandatory)]
        [AtlasNode[]] $KnownNode
    )

    $result = [AtlasCollectionResult]::new()
    $keyById = @{}
    $keyByAppId = @{}
    foreach ($node in $KnownNode) {
        if (-not $keyById.ContainsKey($node.Id) -or $node.Status -eq 'complete') {
            $keyById[$node.Id] = $node.Key
        }
        if ($node.Kind -eq 'servicePrincipal' -and $node.Properties.ContainsKey('appId') -and $node.Properties.appId) {
            $keyByAppId[$node.Properties.appId] = $node.Key
        }
    }

    $endpoint = '/v1.0/identity/conditionalAccess/policies'
    try {
        $response = Invoke-AtlasGraphRequest -Uri $endpoint
    }
    catch {
        $result.Status = 'partial'
        $result.Warnings.Add("Conditional Access policies could not be collected: $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
        $result.Metrics = @{
            policyCount = 0
            assignmentEdgeCount = 0
            requestCount = 0
            retryCount = 0
        }
        return $result
    }

    $addedNode = @{}
    foreach ($policy in $response.Items) {
        $conditions = Get-AtlasResponseProperty -InputObject $policy -Name 'conditions'
        $users = Get-AtlasResponseProperty -InputObject $conditions -Name 'users'
        $applications = Get-AtlasResponseProperty -InputObject $conditions -Name 'applications'
        $grantControls = Get-AtlasResponseProperty -InputObject $policy -Name 'grantControls'
        $sessionControls = Get-AtlasResponseProperty -InputObject $policy -Name 'sessionControls'

        $policyNode = New-AtlasNode -TenantId $TenantId -Id $policy.id -Kind 'conditionalAccessPolicy' -DisplayName $policy.displayName -Properties @{
            state = $policy.state
            createdDateTime = $policy.createdDateTime
            modifiedDateTime = $policy.modifiedDateTime
            includeUserCount = @(Get-AtlasConditionalAccessCollection -Object $users -Name 'includeUsers').Count
            excludeUserCount = @(Get-AtlasConditionalAccessCollection -Object $users -Name 'excludeUsers').Count
            includeGroupCount = @(Get-AtlasConditionalAccessCollection -Object $users -Name 'includeGroups').Count
            excludeGroupCount = @(Get-AtlasConditionalAccessCollection -Object $users -Name 'excludeGroups').Count
            includeApplicationCount = @(Get-AtlasConditionalAccessCollection -Object $applications -Name 'includeApplications').Count
            excludeApplicationCount = @(Get-AtlasConditionalAccessCollection -Object $applications -Name 'excludeApplications').Count
            grantControls = $grantControls
            sessionControls = $sessionControls
        } -Source @{
            provider = 'microsoftGraph'
            apiVersion = 'v1.0'
            odataType = '#microsoft.graph.conditionalAccessPolicy'
            resourcePath = "/identity/conditionalAccess/policies/$($policy.id)"
            collector = 'conditionalAccess'
        }
        $result.Nodes.Add($policyNode)
        $addedNode[$policyNode.Key] = $true

        $assignments = @(
            @{
                Values = @(Get-AtlasConditionalAccessCollection -Object $users -Name 'includeUsers')
                Assignment = 'include'
                Category = 'users'
                SubjectKind = 'user'
                Relationship = 'conditionalAccessIncludes'
            }
            @{
                Values = @(Get-AtlasConditionalAccessCollection -Object $users -Name 'excludeUsers')
                Assignment = 'exclude'
                Category = 'users'
                SubjectKind = 'user'
                Relationship = 'conditionalAccessExcludes'
            }
            @{
                Values = @(Get-AtlasConditionalAccessCollection -Object $users -Name 'includeGroups')
                Assignment = 'include'
                Category = 'groups'
                SubjectKind = 'group'
                Relationship = 'conditionalAccessIncludes'
            }
            @{
                Values = @(Get-AtlasConditionalAccessCollection -Object $users -Name 'excludeGroups')
                Assignment = 'exclude'
                Category = 'groups'
                SubjectKind = 'group'
                Relationship = 'conditionalAccessExcludes'
            }
            @{
                Values = @(Get-AtlasConditionalAccessCollection -Object $applications -Name 'includeApplications')
                Assignment = 'include'
                Category = 'applications'
                SubjectKind = 'application'
                Relationship = 'conditionalAccessIncludes'
            }
            @{
                Values = @(Get-AtlasConditionalAccessCollection -Object $applications -Name 'excludeApplications')
                Assignment = 'exclude'
                Category = 'applications'
                SubjectKind = 'application'
                Relationship = 'conditionalAccessExcludes'
            }
        )

        foreach ($assignmentSet in $assignments) {
            foreach ($value in $assignmentSet.Values) {
                if (-not $value -or $value -eq 'None') {
                    continue
                }

                $subjectKey = $null
                if ($assignmentSet.Category -eq 'applications' -and $keyByAppId.ContainsKey($value)) {
                    $subjectKey = $keyByAppId[$value]
                }
                elseif ($keyById.ContainsKey($value)) {
                    $subjectKey = $keyById[$value]
                }
                else {
                    $scopeId = "$($assignmentSet.Category):$value"
                    $displayName = switch ($value) {
                        'All' { "All $($assignmentSet.Category)" }
                        'Office365' { 'Office 365' }
                        'GuestsOrExternalUsers' { 'Guests or external users' }
                        default { $value }
                    }
                    $scopeNode = New-AtlasConditionalAccessScopeNode -TenantId $TenantId -ScopeId $scopeId -DisplayName $displayName -SubjectKind $assignmentSet.SubjectKind
                    if (-not $addedNode.ContainsKey($scopeNode.Key)) {
                        $result.Nodes.Add($scopeNode)
                        $addedNode[$scopeNode.Key] = $true
                    }
                    $subjectKey = $scopeNode.Key
                }

                $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'conditionalAccess' -Endpoint $endpoint -SourceObjectId "$($policy.id)|$($assignmentSet.Assignment)|$($assignmentSet.Category)|$value" -Fields @{
                    policyId = $policy.id
                    policyDisplayName = $policy.displayName
                    assignment = $assignmentSet.Assignment
                    category = $assignmentSet.Category
                    value = $value
                    state = $policy.state
                }
                $result.Evidence.Add($evidence)
                $result.Edges.Add(
                    (New-AtlasEdge -TenantId $TenantId -From $subjectKey -To $policyNode.Key -Relationship $assignmentSet.Relationship -State @{
                        assignment = $assignmentSet.Assignment
                        category = $assignmentSet.Category
                        subjectKind = $assignmentSet.SubjectKind
                        policyState = $policy.state
                    } -EvidenceIds @($evidence.Key) -Source @{
                        collector = 'conditionalAccess'
                    })
                )
            }
        }
    }

    $result.Metrics = @{
        policyCount = $response.Items.Count
        assignmentEdgeCount = $result.Edges.Count
        requestCount = $response.Metrics.requestCount
        retryCount = $response.Metrics.retryCount
    }
    return $result
}
