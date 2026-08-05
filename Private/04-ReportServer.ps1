function Test-AtlasLoopbackPortAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1024, 65535)]
        [int] $Port
    )

    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
    try {
        $listener.Start()
        return $true
    }
    catch [System.Net.Sockets.SocketException] {
        return $false
    }
    finally {
        $listener.Stop()
    }
}

function Start-AtlasReportServer {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Starts only the packaged loopback report server explicitly requested through OpenReport.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ReportRoot,

        [ValidateRange(1024, 65535)]
        [int] $Port = 8766,

        [ValidateRange(0, 50)]
        [int] $PortSearchLimit = 20,

        [switch] $OpenBrowser
    )

    $resolvedRoot = (Resolve-Path -LiteralPath $ReportRoot -ErrorAction Stop).Path
    $moduleRoot = Split-Path -Parent $PSScriptRoot
    $serverScript = Join-Path $moduleRoot 'tools\Start-IdentityAtlasDevServer.ps1'
    if (-not (Test-Path -LiteralPath $serverScript -PathType Leaf)) {
        throw "The Identity Atlas local report server was not found at '$serverScript'."
    }

    $maximumPort = [math]::Min(65535, $Port + $PortSearchLimit)
    $selectedPort = $null
    foreach ($candidatePort in $Port..$maximumPort) {
        if (Test-AtlasLoopbackPortAvailable -Port $candidatePort) {
            $selectedPort = $candidatePort
            break
        }
    }
    if ($null -eq $selectedPort) {
        throw "No available loopback port was found between $Port and $maximumPort."
    }

    $powerShellPath = (Get-Process -Id $PID).Path
    if (-not $powerShellPath) {
        $powerShellPath = (Get-Command pwsh -ErrorAction Stop).Source
    }
    $serverProcess = Start-Process `
        -FilePath $powerShellPath `
        -ArgumentList @(
            '-NoLogo'
            '-NoProfile'
            '-File'
            "`"$serverScript`""
            '-Root'
            "`"$resolvedRoot`""
            '-Port'
            [string] $selectedPort
        ) `
        -WindowStyle Hidden `
        -PassThru

    $reportUrl = "http://127.0.0.1:$selectedPort/"
    $ready = $false
    for ($attempt = 0; $attempt -lt 50; $attempt++) {
        if ($serverProcess.HasExited) {
            break
        }
        try {
            $response = Invoke-WebRequest -Uri $reportUrl -Method Head -TimeoutSec 1 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                $ready = $true
                break
            }
        }
        catch {
            Start-Sleep -Milliseconds 100
        }
    }
    if (-not $ready) {
        if (-not $serverProcess.HasExited) {
            Stop-Process -Id $serverProcess.Id -ErrorAction SilentlyContinue
        }
        throw "The Identity Atlas local report server did not start at $reportUrl."
    }

    Write-Information "Identity Atlas report ready at $reportUrl" -InformationAction Continue
    if ($OpenBrowser) {
        Start-Process -FilePath $reportUrl
    }

    return [pscustomobject] @{
        Url = $reportUrl
        Port = $selectedPort
        ProcessId = $serverProcess.Id
        ReportRoot = $resolvedRoot
    }
}
