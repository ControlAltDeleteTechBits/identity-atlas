[CmdletBinding()]
param(
    [string] $Path,

    [string] $PackagePath,

    [switch] $SkipPackage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Path) {
    $Path = Split-Path -Parent $PSScriptRoot
}

$projectRoot = [System.IO.Path]::GetFullPath($Path)
if (-not [System.IO.Directory]::Exists($projectRoot)) {
    throw "Project path does not exist: $projectRoot"
}

$checks = [System.Collections.Generic.List[object]]::new()

function Add-AtlasGalleryCheck {
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [bool] $Passed,

        [Parameter(Mandatory)]
        [string] $Evidence
    )

    $checks.Add([pscustomobject] @{
        Name = $Name
        Passed = $Passed
        Evidence = $Evidence
    })

    if (-not $Passed) {
        throw "PowerShell Gallery package check failed: $Name. $Evidence"
    }
}

function Get-AtlasNuspecValue {
    param(
        [Parameter(Mandatory)]
        [xml] $Nuspec,

        [Parameter(Mandatory)]
        [string] $Name
    )

    $node = $Nuspec.SelectSingleNode("//*[local-name()='metadata']/*[local-name()='$Name']")
    if (-not $node) {
        return $null
    }

    return $node.InnerText
}

$manifestPath = Join-Path $projectRoot 'IdentityAtlas.psd1'
if (-not [System.IO.File]::Exists($manifestPath)) {
    throw "Identity Atlas manifest does not exist: $manifestPath"
}

$manifest = Import-PowerShellDataFile -Path $manifestPath
$manifestValidation = Test-ModuleManifest -Path $manifestPath
$psData = $manifest.PrivateData.PSData
$prerelease = if ($psData.ContainsKey('Prerelease')) { [string] $psData.Prerelease } else { '' }
$galleryVersion = if ($prerelease) { "$($manifest.ModuleVersion)-$prerelease" } else { [string] $manifest.ModuleVersion }
$graphDependency = @(
    $manifest.RequiredModules |
        Where-Object {
            $_.ModuleName -eq 'Microsoft.Graph.Authentication' -and
            [version] $_.ModuleVersion -ge [version] '2.38.1'
        }
)

Add-AtlasGalleryCheck -Name 'Module identity' -Passed (
    $manifestValidation.Name -eq 'IdentityAtlas' -and
    $manifest.Author -eq 'Mark Oldham' -and
    $manifest.CompanyName -eq 'Control Alt Delete Tech Bits'
) -Evidence 'The package name, author and publisher match the approved Identity Atlas metadata.'

Add-AtlasGalleryCheck -Name 'Stable version' -Passed (
    $manifest.ModuleVersion -eq '1.0.0' -and
    [string]::IsNullOrWhiteSpace($prerelease)
) -Evidence 'The manifest resolves to stable PowerShell Gallery version 1.0.0.'

Add-AtlasGalleryCheck -Name 'PowerShell edition' -Passed (
    @($manifest.CompatiblePSEditions).Count -eq 1 -and
    $manifest.CompatiblePSEditions[0] -eq 'Core' -and
    [version] $manifest.PowerShellVersion -ge [version] '7.0'
) -Evidence 'The package declares PowerShell Core and PowerShell 7 or later.'

Add-AtlasGalleryCheck -Name 'Microsoft Graph dependency' -Passed (
    $graphDependency.Count -eq 1
) -Evidence 'Microsoft.Graph.Authentication 2.38.1 or later is declared as a required module.'

Add-AtlasGalleryCheck -Name 'Gallery links' -Passed (
    $psData.ProjectUri -eq 'https://github.com/ControlAltDeleteTechBits/identity-atlas' -and
    $psData.LicenseUri -eq 'https://github.com/ControlAltDeleteTechBits/identity-atlas/blob/main/LICENSE' -and
    $psData.IconUri -eq 'https://raw.githubusercontent.com/ControlAltDeleteTechBits/identity-atlas/main/Web/assets/brand/identity-atlas-gallery-icon.svg'
) -Evidence 'Project, licence and direct icon links use the approved public repository.'

$galleryIconPath = Join-Path $projectRoot 'Web/assets/brand/identity-atlas-gallery-icon.svg'
Add-AtlasGalleryCheck -Name 'Gallery icon' -Passed (
    [System.IO.File]::Exists($galleryIconPath) -and
    [System.IO.File]::ReadAllText($galleryIconPath) -match 'width="85" height="85"'
) -Evidence 'The Gallery icon is an 85 by 85 transparent SVG asset.'

Add-AtlasGalleryCheck -Name 'Release notes metadata' -Passed (
    -not [string]::IsNullOrWhiteSpace($psData.ReleaseNotes) -and
    $psData.ReleaseNotes -match 'v1\.0\.0'
) -Evidence 'The package metadata links to the matching stable GitHub release.'

if ($SkipPackage) {
    return [pscustomobject] @{
        ProjectRoot = $projectRoot
        Status = 'Passed'
        CheckCount = $checks.Count
        PackagePath = $null
        PackageSha256 = $null
        Checks = @($checks)
    }
}

if (-not $PackagePath) {
    throw 'Pass -PackagePath when package validation is not skipped.'
}
if (-not [System.IO.Path]::IsPathRooted($PackagePath)) {
    $PackagePath = Join-Path $projectRoot $PackagePath
}

$resolvedPackagePath = [System.IO.Path]::GetFullPath($PackagePath)
if (-not [System.IO.File]::Exists($resolvedPackagePath)) {
    throw "PowerShell Gallery package does not exist: $resolvedPackagePath"
}

$expectedPackageName = "IdentityAtlas.$galleryVersion.nupkg"
Add-AtlasGalleryCheck -Name 'Package filename' -Passed (
    [System.IO.Path]::GetFileName($resolvedPackagePath) -ceq $expectedPackageName
) -Evidence "The package filename is $expectedPackageName."

$checksumPath = Join-Path ([System.IO.Path]::GetDirectoryName($resolvedPackagePath)) (
    [System.IO.Path]::GetFileNameWithoutExtension($resolvedPackagePath) + '-SHA256.txt'
)
if (-not [System.IO.File]::Exists($checksumPath)) {
    throw "PowerShell Gallery package checksum does not exist: $checksumPath"
}

$checksumText = [System.IO.File]::ReadAllText($checksumPath).Trim()
$expectedHashMatch = [regex]::Match($checksumText, '^(?<hash>[0-9A-Fa-f]{64})\s+')
$packageHash = (Get-FileHash -LiteralPath $resolvedPackagePath -Algorithm SHA256).Hash
Add-AtlasGalleryCheck -Name 'Package checksum' -Passed (
    $expectedHashMatch.Success -and
    $packageHash -ceq $expectedHashMatch.Groups['hash'].Value.ToUpperInvariant()
) -Evidence "SHA256 $packageHash matches the generated checksum file."

Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::OpenRead($resolvedPackagePath)
try {
    $unsafeEntries = @(
        $archive.Entries |
            Where-Object {
                $_.FullName -match '(?i)(^|/)(Output|Release|Tests|TestResults|work|attachments|\.codex|\.git)(/|$)' -or
                $_.FullName -match '(?i)(^|/)data/report\.json$' -or
                $_.FullName -match '(?i)\.(pfx|p12|key|cer|crt)$'
            }
    )

    $nuspecEntry = $archive.Entries |
        Where-Object { $_.Name -eq 'IdentityAtlas.nuspec' } |
        Select-Object -First 1
    if (-not $nuspecEntry) {
        throw 'The package does not contain IdentityAtlas.nuspec.'
    }

    $reader = [System.IO.StreamReader]::new($nuspecEntry.Open())
    try {
        [xml] $nuspec = $reader.ReadToEnd()
    }
    finally {
        $reader.Dispose()
    }
}
finally {
    $archive.Dispose()
}

Add-AtlasGalleryCheck -Name 'Package content boundary' -Passed (
    $unsafeEntries.Count -eq 0
) -Evidence 'The package contains no report, test fixture, release output, workspace data, Git metadata or certificate file.'

Add-AtlasGalleryCheck -Name 'NuGet package identity' -Passed (
    (Get-AtlasNuspecValue -Nuspec $nuspec -Name 'id') -eq 'IdentityAtlas' -and
    (Get-AtlasNuspecValue -Nuspec $nuspec -Name 'version') -eq $galleryVersion -and
    (Get-AtlasNuspecValue -Nuspec $nuspec -Name 'authors') -eq 'Mark Oldham'
) -Evidence 'The generated NuGet metadata contains the approved package name, version and author.'

Add-AtlasGalleryCheck -Name 'NuGet package links' -Passed (
    (Get-AtlasNuspecValue -Nuspec $nuspec -Name 'projectUrl') -eq $psData.ProjectUri -and
    (Get-AtlasNuspecValue -Nuspec $nuspec -Name 'licenseUrl') -eq $psData.LicenseUri -and
    (Get-AtlasNuspecValue -Nuspec $nuspec -Name 'iconUrl') -eq $psData.IconUri -and
    -not [string]::IsNullOrWhiteSpace((Get-AtlasNuspecValue -Nuspec $nuspec -Name 'releaseNotes'))
) -Evidence 'The generated NuGet metadata includes project, licence, icon and release note links.'

$dependencyNode = $nuspec.SelectSingleNode("//*[local-name()='dependency'][@id='Microsoft.Graph.Authentication']")
Add-AtlasGalleryCheck -Name 'NuGet dependency' -Passed (
    $null -ne $dependencyNode -and
    [version] $dependencyNode.version -ge [version] '2.38.1'
) -Evidence 'The generated package declares Microsoft.Graph.Authentication 2.38.1 or later.'

$temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
$temporaryPrefix = $temporaryRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
$localRepositoryName = "IdentityAtlasGalleryAudit$([guid]::NewGuid().ToString('N'))"
$localSaveRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $temporaryRoot "IdentityAtlasGallerySave-$([guid]::NewGuid().ToString('N'))")
)
if (-not $localSaveRoot.StartsWith($temporaryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'The local Gallery save path is outside the system temporary directory.'
}

try {
    Register-PSResourceRepository `
        -Name $localRepositoryName `
        -Uri ([System.IO.Path]::GetDirectoryName($resolvedPackagePath)) `
        -Trusted

    $findParameters = @{
        Name = 'IdentityAtlas'
        Version = $galleryVersion
        Repository = $localRepositoryName
        ErrorAction = 'Stop'
    }
    if ($prerelease) {
        $findParameters.Prerelease = $true
    }
    $foundPackage = Find-PSResource @findParameters

    [System.IO.Directory]::CreateDirectory($localSaveRoot) | Out-Null
    $saveParameters = @{
        Name = 'IdentityAtlas'
        Version = $galleryVersion
        Repository = $localRepositoryName
        Path = $localSaveRoot
        SkipDependencyCheck = $true
        PassThru = $true
        ErrorAction = 'Stop'
    }
    if ($prerelease) {
        $saveParameters.Prerelease = $true
    }
    $savedPackage = Save-PSResource @saveParameters

    Add-AtlasGalleryCheck -Name 'Local repository discovery' -Passed (
        $foundPackage.Name -eq 'IdentityAtlas' -and
        $foundPackage.Version.ToString() -eq $manifest.ModuleVersion -and
        ([string] $foundPackage.Prerelease) -eq $prerelease -and
        $savedPackage.Name -eq 'IdentityAtlas' -and
        @(Get-ChildItem -LiteralPath $localSaveRoot -Recurse -File).Count -gt 0
    ) -Evidence 'PSResourceGet discovered and saved the stable package through an isolated local repository.'
}
finally {
    Unregister-PSResourceRepository -Name $localRepositoryName -ErrorAction SilentlyContinue
    if ([System.IO.Directory]::Exists($localSaveRoot)) {
        $validatedSaveRoot = [System.IO.Path]::GetFullPath($localSaveRoot)
        if (-not $validatedSaveRoot.StartsWith($temporaryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'Refusing to remove a local Gallery save directory outside the system temporary directory.'
        }
        [System.IO.Directory]::Delete($validatedSaveRoot, $true)
    }
}

$extractRoot = [System.IO.Path]::GetFullPath(
    (Join-Path $temporaryRoot "IdentityAtlasGalleryAudit-$([guid]::NewGuid().ToString('N'))")
)
if (-not $extractRoot.StartsWith($temporaryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'The Gallery package audit path is outside the system temporary directory.'
}

try {
    [System.IO.Compression.ZipFile]::ExtractToDirectory($resolvedPackagePath, $extractRoot)
    $extractedManifestPath = Join-Path $extractRoot 'IdentityAtlas.psd1'
    $packageScan = & (Join-Path $PSScriptRoot 'Test-IdentityAtlasRelease.ps1') -Path $extractRoot
    Test-ModuleManifest -Path $extractedManifestPath | Out-Null

    $powerShellCommand = Get-Command pwsh -ErrorAction Stop
    $previousManifestPath = $env:IDENTITY_ATLAS_GALLERY_MANIFEST
    try {
        $env:IDENTITY_ATLAS_GALLERY_MANIFEST = $extractedManifestPath
        $importedCommands = @(
            & $powerShellCommand.Source -NoLogo -NoProfile -Command '
                Import-Module $env:IDENTITY_ATLAS_GALLERY_MANIFEST -Force -ErrorAction Stop
                Get-Command -Module IdentityAtlas | Select-Object -ExpandProperty Name | Sort-Object
            '
        )
        if ($LASTEXITCODE -ne 0) {
            throw 'A clean PowerShell process could not import the generated Gallery package.'
        }
    }
    finally {
        $env:IDENTITY_ATLAS_GALLERY_MANIFEST = $previousManifestPath
    }

    $expectedCommands = @(
        'Compare-IdentityAtlas'
        'Connect-IdentityAtlas'
        'Export-IdentityAtlas'
        'Invoke-IdentityAtlas'
    )
    $commandDifference = @(Compare-Object -ReferenceObject $expectedCommands -DifferenceObject $importedCommands)

    Add-AtlasGalleryCheck -Name 'Extracted package safety' -Passed (
        $packageScan.Findings -eq 0
    ) -Evidence "$($packageScan.ScannedFiles) packaged text files passed the tenant-data and secret scan."

    Add-AtlasGalleryCheck -Name 'Clean package import' -Passed (
        $commandDifference.Count -eq 0
    ) -Evidence 'A clean PowerShell process imported the package and found all four approved public commands.'
}
finally {
    if ([System.IO.Directory]::Exists($extractRoot)) {
        $validatedExtractRoot = [System.IO.Path]::GetFullPath($extractRoot)
        if (-not $validatedExtractRoot.StartsWith($temporaryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            throw 'Refusing to remove a Gallery audit directory outside the system temporary directory.'
        }
        [System.IO.Directory]::Delete($validatedExtractRoot, $true)
    }
}

[pscustomobject] @{
    ProjectRoot = $projectRoot
    Status = 'Passed'
    CheckCount = $checks.Count
    PackagePath = $resolvedPackagePath
    PackageSha256 = $packageHash
    Checks = @($checks)
}
