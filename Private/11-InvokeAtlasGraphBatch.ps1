function ConvertTo-AtlasBatchRelativeUri {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Uri
    )

    if (-not (Test-AtlasGraphUri -Uri $Uri)) {
        throw 'The Microsoft Graph batch subrequest URI was rejected.'
    }

    if ($Uri -match '^/v1\.0(?<relative>/.*)$') {
        return $Matches.relative
    }

    $absoluteUri = [uri] $Uri
    if ($absoluteUri.AbsolutePath -notmatch '^/v1\.0(?<relative>/.*)$') {
        throw 'Microsoft Graph batching currently supports v1.0 subrequests only.'
    }

    return "$($Matches.relative)$($absoluteUri.Query)"
}

function Get-AtlasGraphStatusCode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord] $ErrorRecord
    )

    if ($ErrorRecord.Exception.PSObject.Properties['ResponseStatusCode']) {
        return [int] $ErrorRecord.Exception.ResponseStatusCode
    }
    if (
        $ErrorRecord.Exception.PSObject.Properties['Response'] -and
        $ErrorRecord.Exception.Response -and
        $ErrorRecord.Exception.Response.PSObject.Properties['StatusCode']
    ) {
        return [int] $ErrorRecord.Exception.Response.StatusCode
    }
    return 0
}

function Invoke-AtlasGraphBatchTransport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Body,

        [ValidateRange(0, 10)]
        [int] $MaximumRetryCount = 5
    )

    $attempt = 0
    $retryCount = 0
    while ($true) {
        try {
            Update-AtlasProgressRequest -RequestIncrement 1 -Status 'Requesting a Microsoft Graph GET batch'
            $response = Invoke-MgGraphRequest `
                -Method POST `
                -Uri '/v1.0/$batch' `
                -Body $Body `
                -ContentType 'application/json' `
                -OutputType PSObject
            return [pscustomobject] @{
                Response = $response
                RequestCount = $retryCount + 1
                RetryCount = $retryCount
            }
        }
        catch {
            $attempt++
            $statusCode = Get-AtlasGraphStatusCode -ErrorRecord $_
            if ($attempt -gt $MaximumRetryCount -or $statusCode -notin @(429, 502, 503, 504)) {
                throw
            }

            $retryCount++
            $retryAfterSeconds = [math]::Min(60, [math]::Pow(2, $attempt))
            $retryReason = if ($statusCode -eq 429) {
                'Microsoft Graph throttled a GET batch'
            }
            else {
                "Microsoft Graph returned HTTP $statusCode for a GET batch"
            }
            Update-AtlasProgressRequest `
                -RetryIncrement 1 `
                -Status "$retryReason. Retrying in $retryAfterSeconds seconds"
            Write-Warning (
                "$retryReason. Retrying in $retryAfterSeconds seconds " +
                "(attempt $attempt of $MaximumRetryCount)."
            )
            Start-Sleep -Seconds $retryAfterSeconds
        }
    }
}

function Invoke-AtlasGraphBatchGet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [object[]] $Request,

        [ValidateRange(1, 20)]
        [int] $BatchSize = 10,

        [ValidateRange(0, 10)]
        [int] $MaximumRetryCount = 5,

        [string] $ProgressStatus = 'Processing Microsoft Graph requests'
    )

    if (-not (Get-Command -Name Invoke-MgGraphRequest -ErrorAction SilentlyContinue)) {
        throw 'Microsoft.Graph.Authentication is required for Microsoft Graph batching.'
    }

    $requestById = @{}
    $orderedRequest = @()
    foreach ($entry in $Request) {
        $id = [string] (Get-AtlasResponseProperty -InputObject $entry -Name 'Id')
        $uri = [string] (Get-AtlasResponseProperty -InputObject $entry -Name 'Uri')
        if ($id -notmatch '^[A-Za-z0-9_-]{1,64}$') {
            throw 'Every Microsoft Graph batch request requires a short alphanumeric ID.'
        }
        if ($requestById.ContainsKey($id)) {
            throw "Microsoft Graph batch request ID '$id' is duplicated."
        }

        $normalised = [pscustomobject] @{
            Id = $id
            Uri = $uri
            RelativeUri = ConvertTo-AtlasBatchRelativeUri -Uri $uri
        }
        $requestById[$id] = $normalised
        $orderedRequest += $normalised
    }

    $resultById = @{}
    $attemptById = @{}
    $pending = @($orderedRequest)
    $batchRequestCount = 0
    $retryCount = 0

    while ($pending.Count -gt 0) {
        $retryPending = [System.Collections.Generic.List[object]]::new()
        for ($offset = 0; $offset -lt $pending.Count; $offset += $BatchSize) {
            $lastIndex = [math]::Min($pending.Count - 1, $offset + $BatchSize - 1)
            $chunk = @($pending[$offset..$lastIndex])
            $payload = @{
                requests = @(
                    foreach ($item in $chunk) {
                        @{
                            id = $item.Id
                            method = 'GET'
                            url = $item.RelativeUri
                        }
                    }
                )
            } | ConvertTo-Json -Depth 8 -Compress

            $transport = Invoke-AtlasGraphBatchTransport `
                -Body $payload `
                -MaximumRetryCount $MaximumRetryCount
            $batchRequestCount += $transport.RequestCount
            $retryCount += $transport.RetryCount
            $responseCollection = @(
                @(Get-AtlasResponseProperty -InputObject $transport.Response -Name 'responses') |
                    Where-Object { $null -ne $_ }
            )
            $responseById = @{}
            foreach ($subresponse in $responseCollection) {
                $responseById[[string] (Get-AtlasResponseProperty -InputObject $subresponse -Name 'id')] = $subresponse
            }

            foreach ($item in $chunk) {
                if (-not $responseById.ContainsKey($item.Id)) {
                    $resultById[$item.Id] = [pscustomobject] @{
                        Id = $item.Id
                        Uri = $item.Uri
                        StatusCode = 500
                        Items = @()
                        ErrorMessage = 'Microsoft Graph did not return a response for this batch item.'
                    }
                    continue
                }

                $subresponse = $responseById[$item.Id]
                $statusCode = [int] (Get-AtlasResponseProperty -InputObject $subresponse -Name 'status')
                $body = Get-AtlasResponseProperty -InputObject $subresponse -Name 'body'
                if ($statusCode -in 429, 502, 503, 504) {
                    $attempt = if ($attemptById.ContainsKey($item.Id)) { $attemptById[$item.Id] + 1 } else { 1 }
                    $attemptById[$item.Id] = $attempt
                    if ($attempt -le $MaximumRetryCount) {
                        $retryPending.Add($item)
                        $retryCount++
                        continue
                    }
                }

                if ($statusCode -ge 200 -and $statusCode -lt 300) {
                    $hasValue = if ($body -is [System.Collections.IDictionary]) {
                        $body.Contains('value')
                    }
                    else {
                        $body -and $null -ne $body.PSObject.Properties['value']
                    }
                    $items = if ($hasValue) {
                        @(
                            @(Get-AtlasResponseProperty -InputObject $body -Name 'value') |
                                Where-Object { $null -ne $_ }
                        )
                    }
                    elseif ($null -ne $body) {
                        @($body)
                    }
                    else {
                        @()
                    }

                    $nextLink = Get-AtlasResponseProperty -InputObject $body -Name '@odata.nextLink'
                    if ($nextLink) {
                        $remaining = Invoke-AtlasGraphRequest `
                            -Uri $nextLink `
                            -MaximumRetryCount $MaximumRetryCount
                        $items += @($remaining.Items)
                        $batchRequestCount += $remaining.Metrics.requestCount
                        $retryCount += $remaining.Metrics.retryCount
                    }

                    $resultById[$item.Id] = [pscustomobject] @{
                        Id = $item.Id
                        Uri = $item.Uri
                        StatusCode = $statusCode
                        Items = @($items)
                        ErrorMessage = $null
                    }
                }
                else {
                    $graphError = Get-AtlasResponseProperty -InputObject $body -Name 'error'
                    $message = [string] (Get-AtlasResponseProperty -InputObject $graphError -Name 'message')
                    $message = ($message -replace '\s+', ' ').Trim()
                    if (-not $message) {
                        $message = 'Microsoft Graph rejected the batch subrequest.'
                    }
                    if ($message.Length -gt 240) {
                        $message = "$($message.Substring(0, 237))..."
                    }
                    $resultById[$item.Id] = [pscustomobject] @{
                        Id = $item.Id
                        Uri = $item.Uri
                        StatusCode = $statusCode
                        Items = @()
                        ErrorMessage = "HTTP $statusCode. $message"
                    }
                }
            }

            $completedCount = $resultById.Count
            Update-AtlasProgressItem `
                -CurrentItem $completedCount `
                -TotalItems $orderedRequest.Count `
                -Status $ProgressStatus
        }

        if ($retryPending.Count -gt 0) {
            $retryDelay = [math]::Min(60, [math]::Pow(2, ($attemptById.Values | Measure-Object -Maximum).Maximum))
            Update-AtlasProgressRequest `
                -RetryIncrement $retryPending.Count `
                -Status "Microsoft Graph throttled $($retryPending.Count) batch items. Retrying in $retryDelay seconds"
            Write-Warning (
                "Microsoft Graph throttled or temporarily rejected $($retryPending.Count) GET batch items. " +
                "Retrying in $retryDelay seconds."
            )
            Start-Sleep -Seconds $retryDelay
        }
        $pending = @($retryPending)
    }

    return [pscustomobject] @{
        Responses = @(
            foreach ($item in $orderedRequest) {
                $resultById[$item.Id]
            }
        )
        Metrics = @{
            logicalRequestCount = $orderedRequest.Count
            requestCount = $batchRequestCount
            retryCount = $retryCount
            batchSize = $BatchSize
        }
    }
}
