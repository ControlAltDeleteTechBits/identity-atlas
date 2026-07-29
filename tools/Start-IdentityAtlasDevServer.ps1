[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $Root,

    [ValidateRange(1024, 65535)]
    [int] $Port = 8765,

    [ValidateRange(1, 30)]
    [int] $RequestTimeoutSeconds = 5
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$resolvedRoot = [System.IO.Path]::GetFullPath($Root)
if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
    throw "The web root '$resolvedRoot' does not exist."
}

$indexPath = Join-Path $resolvedRoot 'index.html'
$manifestPath = Join-Path $resolvedRoot 'data\manifest.js'
$packagePath = Join-Path $resolvedRoot '.identity-atlas-report.json'
foreach ($requiredPath in @($indexPath, $manifestPath, $packagePath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "The web root is not a complete Identity Atlas report. Required file '$requiredPath' is missing."
    }
}

try {
    $packageMetadata = Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json
}
catch {
    throw "The Identity Atlas report package marker is invalid: $($_.Exception.Message)"
}
if ($packageMetadata.format -ne 'IdentityAtlasReport') {
    throw 'The report package marker does not identify an Identity Atlas report.'
}

$manifestContent = Get-Content -LiteralPath $manifestPath -Raw
$manifestMatch = [regex]::Match(
    $manifestContent,
    '^window\.IdentityAtlasData\.registerManifest\((?<json>.*)\);\s*$',
    [System.Text.RegularExpressions.RegexOptions]::Singleline
)
if (-not $manifestMatch.Success) {
    throw 'The report manifest wrapper is invalid.'
}
try {
    $manifest = $manifestMatch.Groups['json'].Value | ConvertFrom-Json
}
catch {
    throw "The report manifest JSON is invalid: $($_.Exception.Message)"
}

if ($manifest.dataOrigin -notin @('LiveTenant', 'SampleFixture')) {
    throw 'The report manifest does not contain a recognised data origin.'
}
if ($packageMetadata.dataOrigin -ne $manifest.dataOrigin) {
    throw 'The report package marker and manifest data origins do not match.'
}
if ($manifest.dataOrigin -eq 'SampleFixture') {
    throw 'Refusing to serve sample fixture data. Identity Atlas reports must be collected from a live tenant.'
}

$contentTypes = @{
    '.html' = 'text/html; charset=utf-8'
    '.css' = 'text/css; charset=utf-8'
    '.js' = 'text/javascript; charset=utf-8'
    '.json' = 'application/json; charset=utf-8'
    '.svg' = 'image/svg+xml'
    '.png' = 'image/png'
    '.md' = 'text/markdown; charset=utf-8'
}

$rootPrefix = $resolvedRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
$listener.Start()
Write-Information "Serving the $($manifest.dataOrigin) Identity Atlas report at http://127.0.0.1:$Port/ from '$resolvedRoot'." -InformationAction Continue

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $timeoutMilliseconds = $RequestTimeoutSeconds * 1000
            $client.ReceiveTimeout = $timeoutMilliseconds
            $client.SendTimeout = $timeoutMilliseconds
            $stream = $client.GetStream()
            $reader = [System.IO.StreamReader]::new($stream, [System.Text.Encoding]::ASCII, $false, 4096, $true)
            $requestLine = $reader.ReadLine()
            $headerCount = 0
            $headerLength = 0
            while ($true) {
                $headerLine = $reader.ReadLine()
                if ([string]::IsNullOrEmpty($headerLine)) {
                    break
                }
                $headerCount++
                $headerLength += $headerLine.Length
                if ($headerCount -gt 100 -or $headerLength -gt 16384) {
                    break
                }
            }

            $responseDetails = [ordered] @{
                Status = '400 Bad Request'
                Body = [System.Text.Encoding]::UTF8.GetBytes('Bad request')
                ContentType = 'text/plain; charset=utf-8'
                SendBody = $true
            }

            if (-not $requestLine) {
                $responseDetails.Status = '400 Bad Request'
            }
            elseif ($requestLine.Length -gt 4096) {
                $responseDetails.Status = '414 URI Too Long'
                $responseDetails.Body = [System.Text.Encoding]::UTF8.GetBytes('URI too long')
            }
            elseif ($headerCount -gt 100 -or $headerLength -gt 16384) {
                $responseDetails.Status = '431 Request Header Fields Too Large'
                $responseDetails.Body = [System.Text.Encoding]::UTF8.GetBytes('Request headers too large')
            }
            else {
                $parts = $requestLine.Split(' ')
                $method = if ($parts.Count -ge 1) { $parts[0] } else { '' }
                if ($parts.Count -lt 3 -or $method -notin @('GET', 'HEAD') -or $parts[2] -notmatch '^HTTP/1\.[01]$') {
                    $responseDetails.Status = if ($method -and $method -notin @('GET', 'HEAD')) {
                        '405 Method Not Allowed'
                    }
                    else {
                        '400 Bad Request'
                    }
                    $responseText = if ($responseDetails.Status -like '405*') {
                        'Method not allowed'
                    }
                    else {
                        'Bad request'
                    }
                    $responseDetails.Body = [System.Text.Encoding]::UTF8.GetBytes($responseText)
                }
                else {
                    $responseDetails.SendBody = $method -ne 'HEAD'
                    try {
                        $requestPath = [System.Uri]::UnescapeDataString($parts[1].Split('?')[0]).TrimStart('/', '\')
                    }
                    catch {
                        $requestPath = $null
                    }

                    if ($null -eq $requestPath -or $requestPath.Contains([char] 0)) {
                        $responseDetails.Status = '400 Bad Request'
                    }
                    else {
                        if (-not $requestPath) {
                            $requestPath = 'index.html'
                        }

                        $relativePath = $requestPath.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
                        $candidate = [System.IO.Path]::GetFullPath((Join-Path $resolvedRoot $relativePath))
                        if (-not $candidate.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                            $responseDetails.Status = '403 Forbidden'
                            $responseDetails.Body = [System.Text.Encoding]::UTF8.GetBytes('Forbidden')
                        }
                        elseif (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
                            $responseDetails.Status = '404 Not Found'
                            $responseDetails.Body = [System.Text.Encoding]::UTF8.GetBytes('Not found')
                        }
                        else {
                            $responseDetails.Status = '200 OK'
                            $responseDetails.Body = [System.IO.File]::ReadAllBytes($candidate)
                            $extension = [System.IO.Path]::GetExtension($candidate).ToLowerInvariant()
                            $responseDetails.ContentType = if ($contentTypes.ContainsKey($extension)) {
                                $contentTypes[$extension]
                            }
                            else {
                                'application/octet-stream'
                            }
                        }
                    }
                }
            }

            $securityHeaders = @(
                "HTTP/1.1 $($responseDetails.Status)"
                "Content-Type: $($responseDetails.ContentType)"
                "Content-Length: $($responseDetails.Body.Length)"
                'Cache-Control: no-store, max-age=0'
                'Pragma: no-cache'
                'X-Content-Type-Options: nosniff'
                'X-Frame-Options: DENY'
                'Referrer-Policy: no-referrer'
                'Cross-Origin-Opener-Policy: same-origin'
                'Cross-Origin-Resource-Policy: same-origin'
                'Permissions-Policy: camera=(), geolocation=(), microphone=(), payment=(), usb=()'
                "Content-Security-Policy: default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data: blob:; worker-src blob:; connect-src 'none'; font-src 'self'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
                'Connection: close'
                ''
                ''
            )
            $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($securityHeaders -join "`r`n")
            $stream.Write($headerBytes, 0, $headerBytes.Length)
            if ($responseDetails.SendBody) {
                $stream.Write($responseDetails.Body, 0, $responseDetails.Body.Length)
            }
            $stream.Flush()
        }
        catch [System.IO.IOException] {
            Write-Verbose "The client disconnected before the response completed: $($_.Exception.Message)"
        }
        finally {
            $client.Dispose()
        }
    }
}
finally {
    $listener.Stop()
}
