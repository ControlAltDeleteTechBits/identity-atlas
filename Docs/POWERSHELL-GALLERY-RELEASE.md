# Identity Atlas PowerShell Gallery release procedure

Date: 5 August 2026

Target Gallery version: `0.16.0-preview1`

Matching GitHub version: `v0.16.0-preview.1`

Publisher: Control Alt Delete Tech Bits

## Current status

1. `IdentityAtlas` version `0.16.0-preview1` was published on 5 August 2026.
2. The publisher is `ControlAltDeleteTechBits`.
3. The matching GitHub prerelease is immutable and contains the verified ZIP and SHA256 file.
4. The PowerShell, JavaScript, release security and Gallery package tests passed.
5. The public Gallery package hash matches the tested local NuGet package.
6. Public discovery, dependency acquisition and isolated import passed after publication.

## Publisher account

1. Open https://www.powershellgallery.com and select Sign in.
2. Use an email-enabled Microsoft account controlled by Control Alt Delete Tech Bits.
3. Register the Gallery username `ControlAltDeleteTechBits` if it remains available.
4. Confirm the account email address and enable the available account security controls.
5. Open the Gallery account page and generate the publishing API key only when the tested package is ready.
6. Never paste the API key into an issue, pull request, chat, source file, command-history file or GitHub secret during the first manual publication.

The Gallery username cannot be changed after registration. Confirm the spelling before completing the account form.

## Build order

Run the complete test suite:

```powershell
.\build.ps1 -NodePath C:\path\to\node.exe
```

Build the GitHub release archive first:

```powershell
.\tools\New-IdentityAtlasRelease.ps1 `
    -OutputPath .\Release `
    -NodePath C:\path\to\node.exe `
    -SkipTests
```

Run the public release package gate:

```powershell
.\tools\Test-IdentityAtlasPublicRelease.ps1 `
    -ReleasePath .\Release\IdentityAtlas-v0.16.0-preview.1.zip
```

Build the Gallery package from that exact release archive:

```powershell
.\tools\New-IdentityAtlasGalleryPackage.ps1 `
    -OutputPath .\Gallery `
    -ReleasePath .\Release\IdentityAtlas-v0.16.0-preview.1.zip
```

Run the Gallery package gate independently:

```powershell
.\tools\Test-IdentityAtlasGalleryPackage.ps1 `
    -PackagePath .\Gallery\IdentityAtlas.0.16.0-preview1.nupkg
```

## Publication order

1. Merge the tested changes to `main` through the protected pull request process.
2. Confirm the GitHub validation workflow passes.
3. Rebuild both packages from the final `main` commit.
4. Run the complete Git history and package security gate.
5. Create the immutable `v0.16.0-preview.1` Git tag.
6. Publish the GitHub prerelease and its ZIP and SHA256 files.
7. Download the public GitHub ZIP and confirm its checksum.
8. Rebuild or verify the Gallery NuGet package against that exact ZIP.
9. Enter the Gallery API key through a hidden PowerShell prompt.
10. Run the Gallery publication command with `WhatIf` and review the output.
11. Publish the already tested NuGet package.
12. Reset the Gallery API key after the first publication.

## Controlled publication command

PowerShell Gallery publication must use the tested `.nupkg` file rather than rebuilding from the repository during submission.

```powershell
$galleryKeySecure = Read-Host 'PowerShell Gallery API key' -AsSecureString
$galleryKey = [System.Net.NetworkCredential]::new('', $galleryKeySecure).Password

try {
    Publish-PSResource `
        -NupkgPath .\Gallery\IdentityAtlas.0.16.0-preview1.nupkg `
        -Repository PSGallery `
        -ApiKey $galleryKey `
        -WhatIf
}
finally {
    $galleryKey = $null
    $galleryKeySecure.Dispose()
}
```

Remove `WhatIf` only after the dry run identifies the correct package, version and repository. The API key must not be displayed or written to disk.

## Post publication validation

1. Confirm the Gallery page names Mark Oldham as author and Control Alt Delete Tech Bits as publisher.
2. Confirm the project, licence, icon and release note links work.
3. Confirm Microsoft.Graph.Authentication appears as a dependency.
4. Confirm the Gallery displays `0.16.0-preview1` as a prerelease.
5. Find the package from a clean PowerShell 7 session.
6. Install it into an isolated current-user test environment.
7. Confirm all four Identity Atlas commands are exported.
8. Run a Core collection against the authorised development tenant.
9. Confirm the report remains local and contains no fixture data.
10. Record the published package URL, publication date and validation evidence in the project log.

Discovery and installation commands:

```powershell
Find-PSResource IdentityAtlas -Version 0.16.0-preview1 -Prerelease -Repository PSGallery

Install-PSResource IdentityAtlas `
    -Version 0.16.0-preview1 `
    -Prerelease `
    -Scope CurrentUser `
    -TrustRepository
```

## Publication boundary

The initial Gallery release is manual. GitHub Actions has read-only repository permissions and contains no PowerShell Gallery API key. Automated publishing can be considered only after the manual process has been proven and a separately reviewed secret-handling design is approved.

## Current publication record

1. Gallery page: https://www.powershellgallery.com/packages/IdentityAtlas/0.16.0-preview1
2. Published at: 5 August 2026 at 08:50:55 UTC.
3. Published NuGet SHA256: `3158CF992E0E5D3A3CC6E2655A35EC14DDF6B03F16750EA997F7E52526043812`.
4. Matching GitHub release: https://github.com/ControlAltDeleteTechBits/identity-atlas/releases/tag/v0.16.0-preview.1
5. Matching GitHub ZIP SHA256: `E1DEB2BE77923076C4AAA53FDA5BC55B3A90AD8D6CA0E525A0C94A0F4B14F132`.
6. The public NuGet package was downloaded after publication and matched the tested package hash.
7. Public discovery, isolated save, dependency acquisition and clean import passed.
8. The isolated import exported `Compare-IdentityAtlas`, `Connect-IdentityAtlas`, `Export-IdentityAtlas` and `Invoke-IdentityAtlas`.
9. The publishing key was restricted to new `IdentityAtlas` package versions and copied only through the local Windows clipboard. The clipboard was cleared immediately after submission.

## Previous publication record

1. Gallery page: https://www.powershellgallery.com/packages/IdentityAtlas/0.15.1-preview1
2. Published at: 4 August 2026 at 12:21:35 UTC.
3. Published NuGet SHA256: `D53795D21C6B90A9BD45EBED480676A0D7B056BD962BAA6684AAFC6193E850DF`.
4. Matching GitHub release: https://github.com/ControlAltDeleteTechBits/identity-atlas/releases/tag/v0.15.1-preview.1
5. Matching GitHub ZIP SHA256: `3086FB203C0C3E174EE0D7FBC185DDBDC58BFFE6C61180E4A091280663AF4875`.
6. The public NuGet package was downloaded again after publication and matched the tested package hash.
7. `Microsoft.Graph.Authentication` version 2.39.0 was acquired as the compatible dependency during the isolated installation test.
8. The isolated import exported `Compare-IdentityAtlas`, `Connect-IdentityAtlas`, `Export-IdentityAtlas` and `Invoke-IdentityAtlas`.
9. The temporary API key file was protected with Windows user encryption and deleted immediately after publication. No Gallery credential is stored in the repository or GitHub Actions.
