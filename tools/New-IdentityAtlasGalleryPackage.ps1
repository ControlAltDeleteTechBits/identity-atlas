[CmdletBinding()]
param(
    [string] $OutputPath,

    [string] $ReleasePath,

    [ValidatePattern('^$|^[0-9A-Za-z.-]+$')]
    [AllowEmptyString()]
    [string] $GitHubPrereleaseLabel = '',

    [switch] $Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputPath) {
    $OutputPath = Join-Path $projectRoot 'Gallery'
}
elseif (-not [System.IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path $projectRoot $OutputPath
}

$resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
$resolvedProjectRoot = [System.IO.Path]::GetFullPath($projectRoot)
if ($resolvedOutputPath -eq $resolvedProjectRoot) {
    throw 'The Gallery output path cannot be the project root.'
}

$manifestPath = Join-Path $resolvedProjectRoot 'IdentityAtlas.psd1'
$manifest = Import-PowerShellDataFile -Path $manifestPath
$moduleManifest = Test-ModuleManifest -Path $manifestPath
$moduleVersion = $moduleManifest.Version.ToString()
$prerelease = if ($manifest.PrivateData.PSData.ContainsKey('Prerelease')) {
    [string] $manifest.PrivateData.PSData.Prerelease
}
else {
    ''
}
$galleryVersion = if ($prerelease) { "$moduleVersion-$prerelease" } else { $moduleVersion }
$githubVersion = if ($GitHubPrereleaseLabel) { "$moduleVersion-$GitHubPrereleaseLabel" } else { $moduleVersion }

if (-not $ReleasePath) {
    $ReleasePath = Join-Path $resolvedProjectRoot "Release/IdentityAtlas-v$githubVersion.zip"
}
elseif (-not [System.IO.Path]::IsPathRooted($ReleasePath)) {
    $ReleasePath = Join-Path $resolvedProjectRoot $ReleasePath
}

$resolvedReleasePath = [System.IO.Path]::GetFullPath($ReleasePath)
if (-not [System.IO.File]::Exists($resolvedReleasePath)) {
    throw "The matching GitHub release archive does not exist: $resolvedReleasePath"
}

$expectedReleaseName = "IdentityAtlas-v$githubVersion.zip"
if ([System.IO.Path]::GetFileName($resolvedReleasePath) -cne $expectedReleaseName) {
    throw "The Gallery package must be built from $expectedReleaseName."
}

$releaseChecksumPath = Join-Path ([System.IO.Path]::GetDirectoryName($resolvedReleasePath)) (
    [System.IO.Path]::GetFileNameWithoutExtension($resolvedReleasePath) + '-SHA256.txt'
)
if (-not [System.IO.File]::Exists($releaseChecksumPath)) {
    throw "The matching GitHub release checksum does not exist: $releaseChecksumPath"
}

$releaseChecksumText = [System.IO.File]::ReadAllText($releaseChecksumPath).Trim()
$releaseHashMatch = [regex]::Match($releaseChecksumText, '^(?<hash>[0-9A-Fa-f]{64})\s+')
$releaseHash = (Get-FileHash -LiteralPath $resolvedReleasePath -Algorithm SHA256).Hash
if (-not $releaseHashMatch.Success -or $releaseHash -cne $releaseHashMatch.Groups['hash'].Value.ToUpperInvariant()) {
    throw 'The GitHub release archive does not match its SHA256 checksum.'
}

$compressCommand = Get-Command Compress-PSResource -ErrorAction SilentlyContinue
if (-not $compressCommand) {
    throw 'Microsoft.PowerShell.PSResourceGet is required. Install version 1.2.0 or later.'
}
$psResourceGet = Get-Module Microsoft.PowerShell.PSResourceGet -ListAvailable |
    Sort-Object Version -Descending |
    Select-Object -First 1
if (-not $psResourceGet -or $psResourceGet.Version -lt [version] '1.2.0') {
    throw 'Microsoft.PowerShell.PSResourceGet 1.2.0 or later is required.'
}

[System.IO.Directory]::CreateDirectory($resolvedOutputPath) | Out-Null
$packageName = "IdentityAtlas.$galleryVersion.nupkg"
$packagePath = Join-Path $resolvedOutputPath $packageName
$checksumPath = Join-Path $resolvedOutputPath "IdentityAtlas.$galleryVersion-SHA256.txt"

foreach ($existingPath in @($packagePath, $checksumPath)) {
    if ([System.IO.File]::Exists($existingPath)) {
        if (-not $Force) {
            throw "Gallery output already exists: $existingPath. Use -Force only after confirming the target version may be rebuilt."
        }

        $existingParent = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($existingPath))
        if ($existingParent -ne $resolvedOutputPath) {
            throw 'A Gallery output target resolved outside the selected output directory.'
        }
        Remove-Item -LiteralPath $existingPath -Force
    }
}

$temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$temporaryPrefix = $temporaryRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
$stagingRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $temporaryRoot "IdentityAtlasGalleryBuild-$([guid]::NewGuid().ToString('N'))")
)
if (-not $stagingRoot.StartsWith($temporaryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'The Gallery staging path is outside the system temporary directory.'
}

try {
    [System.IO.Directory]::CreateDirectory($stagingRoot) | Out-Null
    Expand-Archive -LiteralPath $resolvedReleasePath -DestinationPath $stagingRoot
    $packageRoot = Join-Path $stagingRoot 'IdentityAtlas'
    $stagedManifestPath = Join-Path $packageRoot 'IdentityAtlas.psd1'
    $stagedManifest = Import-PowerShellDataFile -Path $stagedManifestPath
    $stagedModule = Test-ModuleManifest -Path $stagedManifestPath
    $stagedPrerelease = if ($stagedManifest.PrivateData.PSData.ContainsKey('Prerelease')) {
        [string] $stagedManifest.PrivateData.PSData.Prerelease
    }
    else {
        ''
    }

    if (
        $stagedModule.Version.ToString() -ne $moduleVersion -or
        $stagedPrerelease -ne $prerelease
    ) {
        throw 'The GitHub release archive version does not match the Gallery source manifest.'
    }

    & (Join-Path $PSScriptRoot 'Test-IdentityAtlasRelease.ps1') -Path $packageRoot | Out-Null
    $compressedPackage = Compress-PSResource -Path $packageRoot -DestinationPath $resolvedOutputPath -PassThru
    if ($compressedPackage.FullName -cne $packagePath) {
        throw "Compress-PSResource created an unexpected package: $($compressedPackage.FullName)"
    }

    $packageHash = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash
    "$packageHash  $packageName" | Set-Content -LiteralPath $checksumPath -Encoding utf8NoBOM

    $validation = & (Join-Path $PSScriptRoot 'Test-IdentityAtlasGalleryPackage.ps1') `
        -Path $resolvedProjectRoot `
        -PackagePath $packagePath

    [pscustomobject] @{
        Product = 'Identity Atlas'
        Publisher = 'Control Alt Delete Tech Bits'
        Version = $galleryVersion
        SourceReleasePath = $resolvedReleasePath
        SourceReleaseSha256 = $releaseHash
        PackagePath = $packagePath
        ChecksumPath = $checksumPath
        Sha256 = $packageHash
        ValidationChecks = $validation.CheckCount
        Status = 'Passed'
    }
}
finally {
    if ([System.IO.Directory]::Exists($stagingRoot)) {
        $validatedStagingRoot = [System.IO.Path]::GetFullPath($stagingRoot)
        if (-not $validatedStagingRoot.StartsWith($temporaryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'Refusing to remove a Gallery staging directory outside the system temporary directory.'
        }
        [System.IO.Directory]::Delete($validatedStagingRoot, $true)
    }
}
