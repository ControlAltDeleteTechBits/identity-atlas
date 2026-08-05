function Get-AtlasDeviceAndAuthentication {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TenantId,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AtlasNode[]] $KnownNode,

        [switch] $SkipDeviceOwners,

        [switch] $SkipAuthenticationMethods,

        [ValidateRange(1, 20)]
        [int] $BatchSize = 10
    )

    $result = [AtlasCollectionResult]::new()
    $keyById = @{}
    foreach ($node in $KnownNode) {
        if (-not $keyById.ContainsKey($node.Id) -or $node.Status -eq 'complete') {
            $keyById[$node.Id] = $node.Key
        }
    }

    $devicesEndpoint = '/v1.0/devices?$select=id,displayName,deviceId,operatingSystem,operatingSystemVersion,trustType,isCompliant,isManaged,accountEnabled,approximateLastSignInDateTime'
    $deviceResponse = $null
    try {
        $deviceResponse = Invoke-AtlasGraphRequest -Uri $devicesEndpoint
    }
    catch {
        $result.Status = 'partial'
        $result.Warnings.Add("Devices could not be collected: $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
        $deviceResponse = [pscustomobject] @{
            Items = @()
            Metrics = @{ requestCount = 0; retryCount = 0 }
        }
    }

    $deviceKeyById = @{}
    if ($SkipDeviceOwners) {
        $result.Status = 'partial'
        $result.Warnings.Add('Device owner collection was skipped by request.')
    }
    $deviceIndex = 0
    foreach ($device in $deviceResponse.Items) {
        $deviceIndex++
        $deviceId = Get-AtlasResponseProperty -InputObject $device -Name 'id'
        if (-not $deviceId) {
            continue
        }

        $displayName = Get-AtlasResponseProperty -InputObject $device -Name 'displayName'
        if (-not $displayName) { $displayName = $deviceId }
        $deviceNode = New-AtlasNode -TenantId $TenantId -Id $deviceId -Kind 'device' -DisplayName $displayName -Properties @{
            deviceId = Get-AtlasResponseProperty -InputObject $device -Name 'deviceId'
            operatingSystem = Get-AtlasResponseProperty -InputObject $device -Name 'operatingSystem'
            operatingSystemVersion = Get-AtlasResponseProperty -InputObject $device -Name 'operatingSystemVersion'
            trustType = Get-AtlasResponseProperty -InputObject $device -Name 'trustType'
            isCompliant = Get-AtlasResponseProperty -InputObject $device -Name 'isCompliant'
            isManaged = Get-AtlasResponseProperty -InputObject $device -Name 'isManaged'
            accountEnabled = Get-AtlasResponseProperty -InputObject $device -Name 'accountEnabled'
            approximateLastSignInDateTime = Get-AtlasResponseProperty -InputObject $device -Name 'approximateLastSignInDateTime'
        } -Source @{
            provider = 'microsoftGraph'
            apiVersion = 'v1.0'
            odataType = '#microsoft.graph.device'
            resourcePath = "/devices/$deviceId"
            collector = 'devices'
        }
        $result.Nodes.Add($deviceNode)
        $deviceKeyById[$deviceId] = $deviceNode.Key

        if ($SkipDeviceOwners) {
            Update-AtlasProgressItem `
                -CurrentItem $deviceIndex `
                -TotalItems $deviceResponse.Items.Count `
                -Status 'Device owners skipped'
            continue
        }

        $ownersEndpoint = "/v1.0/devices/$deviceId/registeredOwners?`$select=id,displayName"
        try {
            $ownersResponse = Invoke-AtlasGraphRequest -Uri $ownersEndpoint
            $deviceResponse.Metrics.requestCount += $ownersResponse.Metrics.requestCount
            $deviceResponse.Metrics.retryCount += $ownersResponse.Metrics.retryCount
        }
        catch {
            $result.Status = 'partial'
            $result.Warnings.Add("Registered owners could not be collected for device '$displayName': $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
            Update-AtlasProgressItem `
                -CurrentItem $deviceIndex `
                -TotalItems $deviceResponse.Items.Count `
                -Status 'Device owner request failed'
            continue
        }

        foreach ($owner in $ownersResponse.Items) {
            $ownerId = Get-AtlasResponseProperty -InputObject $owner -Name 'id'
            if (-not $ownerId) {
                continue
            }

            if ($keyById.ContainsKey($ownerId)) {
                $ownerKey = $keyById[$ownerId]
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
                    resourcePath = "/directoryObjects/$ownerId"
                    collector = 'devices'
                }
                $result.Nodes.Add($ownerNode)
                $ownerKey = $ownerNode.Key
            }

            $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'devices' -Endpoint $ownersEndpoint -SourceObjectId "$ownerId|registeredOwner|$deviceId" -Fields @{
                ownerId = $ownerId
                deviceId = $deviceId
            }
            $result.Evidence.Add($evidence)
            $result.Edges.Add(
                (New-AtlasEdge -TenantId $TenantId -From $ownerKey -To $deviceNode.Key -Relationship 'registeredDevice' -State @{
                    assignment = 'registeredOwner'
                } -EvidenceIds @($evidence.Key) -Source @{
                    collector = 'devices'
                })
            )
        }
        Update-AtlasProgressItem `
            -CurrentItem $deviceIndex `
            -TotalItems $deviceResponse.Items.Count `
            -Status 'Device owners'
    }

    $authMethodCount = 0
    $authenticationLogicalRequestCount = 0
    $userNode = @($KnownNode | Where-Object { $_.Kind -in @('user', 'guestUser') })
    if ($SkipAuthenticationMethods) {
        $result.Status = 'partial'
        $result.Warnings.Add('Authentication method collection was skipped by request.')
        Update-AtlasProgressItem `
            -CurrentItem $userNode.Count `
            -TotalItems $userNode.Count `
            -Status 'Authentication methods skipped'
    }
    elseif ($userNode.Count -gt 0) {
        $nodeByBatchId = @{}
        $batchRequest = @(
            for ($index = 0; $index -lt $userNode.Count; $index++) {
                $batchId = "auth-$index"
                $nodeByBatchId[$batchId] = $userNode[$index]
                [pscustomobject] @{
                    Id = $batchId
                    Uri = "/v1.0/users/$($userNode[$index].Id)/authentication/methods"
                }
            }
        )
        $methodsBatch = Invoke-AtlasGraphBatchGet `
            -Request $batchRequest `
            -BatchSize $BatchSize `
            -ProgressStatus 'Authentication methods'
        $deviceResponse.Metrics.requestCount += $methodsBatch.Metrics.requestCount
        $deviceResponse.Metrics.retryCount += $methodsBatch.Metrics.retryCount
        $authenticationLogicalRequestCount = $methodsBatch.Metrics.logicalRequestCount

        $processedUserCount = 0
        foreach ($methodsResponse in $methodsBatch.Responses) {
            $processedUserCount++
            $node = $nodeByBatchId[$methodsResponse.Id]
            $methodsEndpoint = "/v1.0/users/$($node.Id)/authentication/methods"
            if ($methodsResponse.StatusCode -lt 200 -or $methodsResponse.StatusCode -ge 300) {
                $result.Status = 'partial'
                $result.Warnings.Add(
                    "Authentication methods could not be collected for user '$($node.DisplayName)': $($methodsResponse.ErrorMessage)"
                )
                Update-AtlasProgressItem `
                    -CurrentItem $processedUserCount `
                    -TotalItems $userNode.Count `
                    -Status 'Authentication methods'
                continue
            }

            foreach ($method in $methodsResponse.Items) {
                $methodId = Get-AtlasResponseProperty -InputObject $method -Name 'id'
                if (-not $methodId) {
                    continue
                }
                $odataType = Get-AtlasResponseProperty -InputObject $method -Name '@odata.type'
                $methodKind = if ($odataType) { $odataType.Replace('#microsoft.graph.', '') } else { 'authenticationMethod' }
                $methodNode = New-AtlasNode -TenantId $TenantId -Id "$($node.Id):authenticationMethod:$methodId" -Kind 'authenticationMethod' -DisplayName $methodKind -Properties @{
                    methodId = $methodId
                    methodType = $methodKind
                    odataType = $odataType
                } -Source @{
                    provider = 'microsoftGraph'
                    apiVersion = 'v1.0'
                    odataType = $odataType
                    resourcePath = "/users/$($node.Id)/authentication/methods/$methodId"
                    collector = 'authenticationMethods'
                }
                $result.Nodes.Add($methodNode)
                $authMethodCount++

                $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'authenticationMethods' -Endpoint $methodsEndpoint -SourceObjectId "$($node.Id)|authenticationMethod|$methodId" -Fields @{
                    userId = $node.Id
                    methodId = $methodId
                    methodType = $methodKind
                }
                $result.Evidence.Add($evidence)
                $result.Edges.Add(
                    (New-AtlasEdge -TenantId $TenantId -From $node.Key -To $methodNode.Key -Relationship 'hasAuthenticationMethod' -State @{
                        methodType = $methodKind
                    } -EvidenceIds @($evidence.Key) -Source @{
                        collector = 'authenticationMethods'
                    })
                )
            }
            Update-AtlasProgressItem `
                -CurrentItem $processedUserCount `
                -TotalItems $userNode.Count `
                -Status 'Authentication methods'
        }
    }

    $result.Metrics = @{
        deviceCount = $deviceResponse.Items.Count
        authenticationMethodCount = $authMethodCount
        authenticationLogicalRequestCount = $authenticationLogicalRequestCount
        deviceOwnersSkipped = [bool] $SkipDeviceOwners
        authenticationMethodsSkipped = [bool] $SkipAuthenticationMethods
        batchSize = $BatchSize
        requestCount = $deviceResponse.Metrics.requestCount
        retryCount = $deviceResponse.Metrics.retryCount
    }
    return $result
}
