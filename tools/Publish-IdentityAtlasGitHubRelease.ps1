[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)] [ValidatePattern('^v\d+\.\d+\.\d+$')] [string] $Tag,
    [Parameter(Mandatory)] [string] $NotesPath,
    [switch] $Publish
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = 'ControlAltDeleteTechBits/identity-atlas'
$projectRoot = Split-Path -Parent $PSScriptRoot
function Invoke-ReleaseGitHub {
    param([string[]] $Arguments)
    $output = & gh @Arguments
    if ($LASTEXITCODE -ne 0) { throw 'GitHub release operation failed. Any existing draft has been retained for inspection.' }
    return $output
}

Push-Location $projectRoot
try {
    if (@(git status --porcelain).Count) { throw 'Release only from a clean checkout.' }
    $commit = git rev-parse HEAD
    $tagCommit = git rev-parse "$Tag^{commit}"
    if ($LASTEXITCODE -ne 0 -or $commit -ne $tagCommit) { throw 'The existing release tag must point to the checked-out tested commit.' }
    $remote = @(git ls-remote origin "refs/tags/$Tag" "refs/tags/$Tag^{}")
    if ($LASTEXITCODE -ne 0 -or -not ($remote -match "^$commit\s")) { throw 'The remote release tag must resolve to the same commit.' }
    $manifest = Import-PowerShellDataFile (Join-Path $projectRoot 'IdentityAtlas.psd1')
    if ($Tag -ne "v$($manifest.ModuleVersion)") { throw 'Tag and module version differ.' }
    $notes = (Resolve-Path -LiteralPath $NotesPath -ErrorAction Stop).Path
    $null = Get-Command gh -ErrorAction Stop
    & (Join-Path $projectRoot 'tools/New-IdentityAtlasRelease.ps1') -NodePath (Get-Command node -ErrorAction Stop).Source | Out-Null
    $zip = Join-Path $projectRoot "Release/IdentityAtlas-$Tag.zip"
    $checksum = Join-Path $projectRoot "Release/IdentityAtlas-$Tag-SHA256.txt"
    & (Join-Path $projectRoot 'tools/Test-IdentityAtlasPublicRelease.ps1') -ReleasePath $zip | Out-Null
    $expected = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash
    if (-not (Get-Content -LiteralPath $checksum -Raw).Contains($expected)) { throw 'Local checksum mismatch.' }
    if (-not $PSCmdlet.ShouldProcess("$repository $Tag", 'Create draft, upload and verify release assets')) { return }
    $releases = Invoke-ReleaseGitHub -Arguments @('api', "repos/$repository/releases?per_page=100") | ConvertFrom-Json
    $existing = @($releases | Where-Object tag_name -eq $Tag)
    if ($existing.Count -gt 0 -and -not $existing[0].draft) { throw 'This release is already published. Published assets will not be replaced.' }
    if (-not $existing.Count) {
        Invoke-ReleaseGitHub -Arguments @('release', 'create', $Tag, '--repo', $repository, '--verify-tag', '--draft', '--title', "Identity Atlas $Tag", '--notes-file', $notes) | Out-Null
    }
    # Never replace a draft asset silently. Inspect an interrupted draft before retrying.
    if ($existing.Count -and @($existing[0].assets).Count) { throw 'The existing draft contains assets. Inspect it before retrying; no assets have been replaced.' }
    Invoke-ReleaseGitHub -Arguments @('release', 'upload', $Tag, $zip, $checksum, '--repo', $repository) | Out-Null
    $releaseState = Invoke-ReleaseGitHub -Arguments @('release', 'view', $Tag, '--repo', $repository, '--json', 'isDraft,assets') | ConvertFrom-Json
    $expectedAssets = @([IO.Path]::GetFileName($zip), [IO.Path]::GetFileName($checksum))
    if (-not $releaseState.isDraft -or @(Compare-Object $expectedAssets @($releaseState.assets.name)).Count) { throw 'Draft state or asset list changed. Publication refused.' }
    $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $verificationRoot = Join-Path $temporaryRoot "IdentityAtlasDownload-$([guid]::NewGuid().ToString('N'))"
    $null = New-Item -ItemType Directory -Path $verificationRoot
    try {
        Invoke-ReleaseGitHub -Arguments @('release', 'download', $Tag, '--repo', $repository, '--pattern', "IdentityAtlas-$Tag.zip", '--dir', $verificationRoot) | Out-Null
        Invoke-ReleaseGitHub -Arguments @('release', 'download', $Tag, '--repo', $repository, '--pattern', "IdentityAtlas-$Tag-SHA256.txt", '--dir', $verificationRoot) | Out-Null
        $actual = (Get-FileHash -LiteralPath (Join-Path $verificationRoot "IdentityAtlas-$Tag.zip") -Algorithm SHA256).Hash
        if ($actual -ne $expected) { throw 'Downloaded draft archive differs. The release remains a draft.' }
        $downloadedChecksumHash = (Get-FileHash -LiteralPath (Join-Path $verificationRoot "IdentityAtlas-$Tag-SHA256.txt") -Algorithm SHA256).Hash
        if ($downloadedChecksumHash -ne (Get-FileHash -LiteralPath $checksum -Algorithm SHA256).Hash) { throw 'Downloaded checksum file differs. The release remains a draft.' }
        if ($Publish -and $PSCmdlet.ShouldProcess("$repository $Tag", 'Publish verified immutable release')) {
            Invoke-ReleaseGitHub -Arguments @('release', 'edit', $Tag, '--repo', $repository, '--draft=false') | Out-Null
        }
        [pscustomobject]@{ Tag = $Tag; Commit = $commit; Sha256 = $actual; Verified = $true }
    }
    finally {
        $resolvedVerificationRoot = [IO.Path]::GetFullPath($verificationRoot)
        if ($resolvedVerificationRoot.StartsWith($temporaryRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedVerificationRoot -Recurse -Force
        }
    }
}
finally { Pop-Location }
