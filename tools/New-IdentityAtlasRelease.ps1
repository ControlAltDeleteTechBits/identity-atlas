[CmdletBinding()]
param(
    [string] $OutputPath,

    [ValidatePattern('^[0-9A-Za-z.-]+$')]
    [string] $PrereleaseLabel = 'preview.1',

    [switch] $SkipTests,

    [string] $NodePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputPath) {
    $OutputPath = Join-Path $projectRoot 'Release'
}
elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $projectRoot $OutputPath
}

$resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$resolvedProjectRoot = [System.IO.Path]::GetFullPath($projectRoot)
if ($resolvedOutputPath -eq $resolvedProjectRoot) {
    throw 'The release output path cannot be the project root.'
}

& (Join-Path $PSScriptRoot 'Test-IdentityAtlasRelease.ps1') -Path $resolvedProjectRoot | Out-Null

if (-not $SkipTests) {
    & (Join-Path $resolvedProjectRoot 'build.ps1') -NodePath $NodePath | Out-Null
}

$manifestPath = Join-Path $resolvedProjectRoot 'IdentityAtlas.psd1'
$moduleManifest = Test-ModuleManifest -Path $manifestPath
$moduleVersion = $moduleManifest.Version.ToString()
$releaseVersion = "$moduleVersion-$PrereleaseLabel"
$archiveFileName = "IdentityAtlas-v$releaseVersion.zip"
$checksumFileName = "IdentityAtlas-v$releaseVersion-SHA256.txt"

[System.IO.Directory]::CreateDirectory($resolvedOutputPath) | Out-Null

$temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$stagingRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $temporaryRoot "IdentityAtlasRelease-$([guid]::NewGuid().ToString('N'))")
)
$temporaryPrefix = $temporaryRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
if (-not $stagingRoot.StartsWith($temporaryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'The release staging path is outside the system temporary directory.'
}

$packageRoot = Join-Path $stagingRoot 'IdentityAtlas'
$archivePath = Join-Path $resolvedOutputPath $archiveFileName
$checksumPath = Join-Path $resolvedOutputPath $checksumFileName

$rootFiles = @(
    'CHANGELOG.md'
    'IdentityAtlas.psd1'
    'IdentityAtlas.psm1'
    'LICENSE'
    'README.md'
    'SECURITY.md'
    'SUPPORT.md'
    'THIRD-PARTY-NOTICES.md'
)

$runtimeDirectories = @(
    'Private'
    'Public'
    'Schema'
    'Web'
)

try {
    [System.IO.Directory]::CreateDirectory($packageRoot) | Out-Null

    foreach ($fileName in $rootFiles) {
        $sourcePath = Join-Path $resolvedProjectRoot $fileName
        if (-not [System.IO.File]::Exists($sourcePath)) {
            throw "Required release file is missing: $fileName"
        }
        Copy-Item -LiteralPath $sourcePath -Destination (Join-Path $packageRoot $fileName)
    }

    foreach ($directoryName in $runtimeDirectories) {
        $sourcePath = Join-Path $resolvedProjectRoot $directoryName
        if (-not [System.IO.Directory]::Exists($sourcePath)) {
            throw "Required runtime directory is missing: $directoryName"
        }
        Copy-Item -LiteralPath $sourcePath -Destination $packageRoot -Recurse
    }

    $packageToolsPath = Join-Path $packageRoot 'tools'
    [System.IO.Directory]::CreateDirectory($packageToolsPath) | Out-Null
    Copy-Item -LiteralPath (Join-Path $resolvedProjectRoot 'tools\Start-IdentityAtlasDevServer.ps1') -Destination $packageToolsPath

    $stagedManifestPath = Join-Path $packageRoot 'IdentityAtlas.psd1'
    Test-ModuleManifest -Path $stagedManifestPath | Out-Null
    & (Join-Path $PSScriptRoot 'Test-IdentityAtlasRelease.ps1') -Path $packageRoot | Out-Null

    $forbiddenPackagePaths = @(
        Get-ChildItem -LiteralPath $packageRoot -Recurse -Force |
            Where-Object {
                $_.FullName -match '(?i)[\\/](Output|Release|Tests|work|attachments|\.codex)[\\/]' -or
                $_.Name -eq 'report.json'
            }
    )
    if ($forbiddenPackagePaths.Count -gt 0) {
        throw 'The staged release contains a forbidden generated-data path.'
    }

    foreach ($existingPath in @($archivePath, $checksumPath)) {
        if ([System.IO.File]::Exists($existingPath)) {
            $existingParent = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($existingPath))
            if ($existingParent -ne $resolvedOutputPath) {
                throw 'A release output target resolved outside the selected output directory.'
            }
            Remove-Item -LiteralPath $existingPath -Force
        }
    }

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory(
        $stagingRoot,
        $archivePath,
        [System.IO.Compression.CompressionLevel]::Optimal,
        $false
    )

    $archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $forbiddenEntries = @(
            $archive.Entries |
                Where-Object {
                    $_.FullName -match '(?i)(^|/)(Output|Release|Tests|work|attachments|\.codex)(/|$)' -or
                    $_.FullName -match '(?i)(^|/)data/report\.json$'
                }
        )
        if ($forbiddenEntries.Count -gt 0) {
            throw 'The release archive contains generated tenant data or a forbidden project directory.'
        }
    }
    finally {
        $archive.Dispose()
    }

    $checksum = Get-FileHash -LiteralPath $archivePath -Algorithm SHA256
    "$($checksum.Hash)  $archiveFileName" |
        Set-Content -LiteralPath $checksumPath -Encoding utf8NoBOM

    [pscustomobject] @{
        Product = 'Identity Atlas'
        Publisher = 'Control Alt Delete Tech Bits'
        Version = $releaseVersion
        ArchivePath = $archivePath
        ChecksumPath = $checksumPath
        Sha256 = $checksum.Hash
    }
}
finally {
    if ([System.IO.Directory]::Exists($stagingRoot)) {
        $validatedStagingRoot = [System.IO.Path]::GetFullPath($stagingRoot)
        if (-not $validatedStagingRoot.StartsWith($temporaryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'Refusing to remove a release staging directory outside the system temporary directory.'
        }
        Remove-Item -LiteralPath $validatedStagingRoot -Recurse -Force
    }
}
