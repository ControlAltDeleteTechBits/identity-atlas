function Get-AtlasResponseProperty {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $InputObject,

        [Parameter(Mandatory)]
        [string] $Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        return $InputObject[$Name]
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -ne $property) {
        return $property.Value
    }

    return $null
}

function Invoke-AtlasGraphRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Uri,

        [hashtable] $Headers = @{},

        [ValidateRange(0, 10)]
        [int] $MaximumRetryCount = 5
    )

    if (-not (Get-Command -Name Invoke-MgGraphRequest -ErrorAction SilentlyContinue)) {
        throw 'Microsoft.Graph.Authentication is required for live collection. Install it with Install-PSResource Microsoft.Graph.Authentication -Scope CurrentUser.'
    }

    $items = [System.Collections.Generic.List[object]]::new()
    $nextLink = $Uri
    $requestCount = 0
    $retryCount = 0
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    while ($nextLink) {
        if (-not (Test-AtlasGraphUri -Uri $nextLink)) {
            throw 'The Microsoft Graph request URI was rejected because its scheme, host or API path is not permitted.'
        }

        $response = $null
        $attempt = 0

        while ($null -eq $response) {
            try {
                $requestCount++
                Update-AtlasProgressRequest -RequestIncrement 1 -Status 'Requesting Microsoft Graph'
                $response = Invoke-MgGraphRequest -Method GET -Uri $nextLink -Headers $Headers -OutputType PSObject
            }
            catch {
                $attempt++

                $statusCode = $null
                if ($_.Exception.PSObject.Properties['ResponseStatusCode']) {
                    $statusCode = [int] $_.Exception.ResponseStatusCode
                }
                elseif (
                    $_.Exception.PSObject.Properties['Response'] -and
                    $_.Exception.Response -and
                    $_.Exception.Response.PSObject.Properties['StatusCode']
                ) {
                    $statusCode = [int] $_.Exception.Response.StatusCode
                }

                if ($attempt -gt $MaximumRetryCount -or $statusCode -notin @(429, 502, 503, 504)) {
                    throw
                }
                $retryCount++

                $retryAfterSeconds = 0
                $responseHeaders = if (
                    $_.Exception.PSObject.Properties['Response'] -and
                    $_.Exception.Response
                ) {
                    $_.Exception.Response.Headers
                }
                else {
                    $null
                }
                $retryAfter = if ($responseHeaders -and $responseHeaders.PSObject.Properties['RetryAfter']) {
                    $responseHeaders.RetryAfter
                }
                else {
                    $null
                }
                if ($retryAfter) {
                    if ($retryAfter.PSObject.Properties['Delta'] -and $retryAfter.Delta) {
                        $retryAfterSeconds = [int] [math]::Ceiling($retryAfter.Delta.TotalSeconds)
                    }
                    elseif ($retryAfter.PSObject.Properties['Date'] -and $retryAfter.Date) {
                        $retryAfterSeconds = [int] [math]::Ceiling(($retryAfter.Date - [datetimeoffset]::UtcNow).TotalSeconds)
                    }
                }
                if ($retryAfterSeconds -le 0) {
                    $retryAfterSeconds = [math]::Min(60, [math]::Pow(2, $attempt))
                }

                $retryReason = if ($statusCode -eq 429) {
                    'Microsoft Graph throttled the request'
                }
                else {
                    "Microsoft Graph returned HTTP $statusCode"
                }
                Update-AtlasProgressRequest `
                    -RetryIncrement 1 `
                    -Status "$retryReason. Retrying in $retryAfterSeconds seconds"
                $progressContext = Get-Variable `
                    -Name IdentityAtlasProgressContext `
                    -Scope Script `
                    -ValueOnly `
                    -ErrorAction SilentlyContinue
                $collectorDisplayName = if ($progressContext -and $progressContext.CollectorDisplayName) {
                    $progressContext.CollectorDisplayName
                }
                else {
                    'Microsoft Graph data'
                }
                Write-Warning (
                    "$retryReason while collecting $collectorDisplayName. " +
                    "Retrying in $retryAfterSeconds seconds (attempt $attempt of $MaximumRetryCount)."
                )
                Start-Sleep -Seconds $retryAfterSeconds
            }
        }

        $hasValueCollection = if ($response -is [System.Collections.IDictionary]) {
            $response.Contains('value')
        }
        else {
            $null -ne $response.PSObject.Properties['value']
        }

        if ($hasValueCollection) {
            $pageItems = Get-AtlasResponseProperty -InputObject $response -Name 'value'
            foreach ($item in @($pageItems)) {
                if ($null -ne $item) {
                    $items.Add($item)
                }
            }
            $nextLink = Get-AtlasResponseProperty -InputObject $response -Name '@odata.nextLink'
        }
        else {
            $items.Add($response)
            $nextLink = $null
        }
    }

    $stopwatch.Stop()
    return [pscustomobject] @{
        Items = $items
        Metrics = @{
            requestCount = $requestCount
            retryCount = $retryCount
            itemCount = $items.Count
            durationMilliseconds = [math]::Round($stopwatch.Elapsed.TotalMilliseconds, 2)
        }
    }
}
