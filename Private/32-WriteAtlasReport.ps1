function Write-AtlasTextFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content
    )

    $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
    $directory = [System.IO.Path]::GetDirectoryName($Path)
    $temporaryPath = Join-Path $directory ".$([System.IO.Path]::GetFileName($Path)).$([guid]::NewGuid().ToString('N')).tmp"
    try {
        [System.IO.File]::WriteAllText($temporaryPath, $Content, $utf8WithoutBom)
        [System.IO.File]::Move($temporaryPath, $Path, $true)
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryPath -Force
        }
    }
}

function Write-AtlasReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject] $Report,

        [Parameter(Mandatory)]
        [string] $OutputPath
    )

    $resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
    $pathRoot = [System.IO.Path]::GetPathRoot($resolvedOutputPath)
    if ($resolvedOutputPath.TrimEnd('\', '/') -eq $pathRoot.TrimEnd('\', '/')) {
        throw 'The report output path cannot be a filesystem root.'
    }

    $projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    if ($resolvedOutputPath.Equals($projectRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'The report output path cannot be the Identity Atlas project root.'
    }
    $protectedSourceDirectory = @('Private', 'Public', 'Schema', 'Tests', 'tools', 'Web')
    foreach ($directoryName in $protectedSourceDirectory) {
        $protectedPath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $directoryName))
        $protectedPrefix = $protectedPath.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
        if (
            $resolvedOutputPath.Equals($protectedPath, [System.StringComparison]::OrdinalIgnoreCase) -or
            $resolvedOutputPath.StartsWith($protectedPrefix, [System.StringComparison]::OrdinalIgnoreCase)
        ) {
            throw "The report output path cannot be inside the project source directory '$directoryName'."
        }
    }

    $webRoot = Join-Path $projectRoot 'Web'
    $assetsSource = Join-Path $webRoot 'assets'

    $null = New-Item -ItemType Directory -Path $resolvedOutputPath -Force
    $assetsOutput = Join-Path $resolvedOutputPath 'assets'
    $dataOutput = Join-Path $resolvedOutputPath 'data'
    $null = New-Item -ItemType Directory -Path $assetsOutput -Force
    $null = New-Item -ItemType Directory -Path $dataOutput -Force

    Copy-Item -LiteralPath (Join-Path $webRoot 'index.html') -Destination (Join-Path $resolvedOutputPath 'index.html') -Force
    Copy-Item -Path (Join-Path $assetsSource '*') -Destination $assetsOutput -Recurse -Force

    $manifestJson = $Report.manifest | ConvertTo-Json -Depth 20 -Compress
    $nodesJson = $Report.nodes | ConvertTo-Json -Depth 20 -Compress
    $edgesJson = $Report.edges | ConvertTo-Json -Depth 20 -Compress
    $evidenceJson = $Report.evidence | ConvertTo-Json -Depth 20 -Compress
    $reportJson = $Report | ConvertTo-Json -Depth 20

    Write-AtlasTextFile -Path (Join-Path $dataOutput 'manifest.js') -Content "window.IdentityAtlasData.registerManifest($manifestJson);"
    Write-AtlasTextFile -Path (Join-Path $dataOutput 'nodes-0001.js') -Content "window.IdentityAtlasData.registerNodes($nodesJson);"
    Write-AtlasTextFile -Path (Join-Path $dataOutput 'edges-0001.js') -Content "window.IdentityAtlasData.registerEdges($edgesJson);"
    Write-AtlasTextFile -Path (Join-Path $dataOutput 'evidence-0001.js') -Content "window.IdentityAtlasData.registerEvidence($evidenceJson);"
    Write-AtlasTextFile -Path (Join-Path $dataOutput 'report.json') -Content $reportJson
    $packageMetadata = [ordered] @{
        format = 'IdentityAtlasReport'
        packageVersion = '2.0.0'
        reportVersion = $Report.manifest.reportVersion
        schemaVersion = $Report.manifest.schemaVersion
        dataOrigin = $Report.manifest.dataOrigin
        generatedAtUtc = $Report.manifest.generatedAtUtc
    } | ConvertTo-Json -Depth 4
    Write-AtlasTextFile -Path (Join-Path $resolvedOutputPath '.identity-atlas-report.json') -Content $packageMetadata

    return Get-Item -LiteralPath (Join-Path $resolvedOutputPath 'index.html')
}
