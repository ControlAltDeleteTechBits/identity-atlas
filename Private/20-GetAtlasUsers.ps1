function Get-AtlasUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TenantId
    )

    $result = [AtlasCollectionResult]::new()
    $endpoint = '/v1.0/users?$select=id,displayName,userPrincipalName,userType,accountEnabled,department,jobTitle,companyName,country,city,officeLocation&$expand=manager($select=id,displayName)'
    $response = Invoke-AtlasGraphRequest -Uri $endpoint

    foreach ($user in $response.Items) {
        $properties = @{
            userPrincipalName = $user.userPrincipalName
            userType = $user.userType
            accountEnabled = $user.accountEnabled
        }
        foreach ($attribute in @('department', 'jobTitle', 'companyName', 'country', 'city', 'officeLocation')) {
            $hasAttribute = if ($user -is [System.Collections.IDictionary]) { $user.Contains($attribute) } else { $null -ne $user.PSObject.Properties[$attribute] }
            if ($hasAttribute) { $properties[$attribute] = Get-AtlasResponseProperty -InputObject $user -Name $attribute }
        }
        $kind = if ($user.userType -eq 'Guest') { 'guestUser' } else { 'user' }
        $manager = Get-AtlasResponseProperty -InputObject $user -Name 'manager'
        $properties.managerId = Get-AtlasResponseProperty -InputObject $manager -Name 'id'
        $properties.managerDisplayName = Get-AtlasResponseProperty -InputObject $manager -Name 'displayName'
        $properties.managerCollectionStatus = if ($null -ne $user.PSObject.Properties['manager'] -or ($user -is [System.Collections.IDictionary] -and $user.Contains('manager'))) { 'collected' } else { 'unknown' }
        $node = New-AtlasNode -TenantId $TenantId -Id $user.id -Kind $kind -DisplayName $user.displayName -Properties $properties -Source @{
            provider = 'microsoftGraph'
            apiVersion = 'v1.0'
            odataType = '#microsoft.graph.user'
            resourcePath = "/users/$($user.id)"
            collector = 'users'
        }
        $result.Nodes.Add($node)
    }

    # Graph can omit a null expanded manager. Resolve omissions with explicit GETs;
    # a denied request must not become a missing-manager finding.
    $unknownManagers = @($result.Nodes | Where-Object { $_.Properties.managerCollectionStatus -eq 'unknown' })
    if ($unknownManagers.Count -gt 0) {
        $managerNodes = @{}
        $managerRequests = @(for ($index = 0; $index -lt $unknownManagers.Count; $index++) {
            $requestId = "manager-$index"
            $managerNodes[$requestId] = $unknownManagers[$index]
            [pscustomobject] @{ Id = $requestId; Uri = "/v1.0/users/$($unknownManagers[$index].Id)/manager?`$select=id,displayName" }
        })
        try {
            $managerBatch = Invoke-AtlasGraphBatchGet -Request $managerRequests -BatchSize 10 -ProgressStatus 'User manager metadata'
            $response.Metrics.requestCount += $managerBatch.Metrics.requestCount
            $response.Metrics.retryCount += $managerBatch.Metrics.retryCount
            foreach ($managerResponse in $managerBatch.Responses) {
                $managerNode = $managerNodes[$managerResponse.Id]
                $managerNode.Properties.managerRequestStatus = $managerResponse.StatusCode
                if ($managerResponse.StatusCode -eq 404) {
                    $managerNode.Properties.managerCollectionStatus = 'collected'
                }
                elseif ($managerResponse.StatusCode -eq 200 -and @($managerResponse.Items).Count -eq 1) {
                    $managerNode.Properties.managerId = Get-AtlasResponseProperty -InputObject $managerResponse.Items[0] -Name id
                    $managerNode.Properties.managerDisplayName = Get-AtlasResponseProperty -InputObject $managerResponse.Items[0] -Name displayName
                    if ($managerNode.Properties.managerId) { $managerNode.Properties.managerCollectionStatus = 'collected' }
                }
                if ($managerNode.Properties.managerCollectionStatus -ne 'collected') {
                    $result.Status = 'partial'
                    $result.Warnings.Add("Manager metadata is unknown for user '$($managerNode.DisplayName)'.")
                }
            }
        }
        catch {
            $result.Status = 'partial'
            $result.Warnings.Add("Manager metadata collection failed: $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
        }
    }
    $result.Metrics = $response.Metrics
    return $result
}
