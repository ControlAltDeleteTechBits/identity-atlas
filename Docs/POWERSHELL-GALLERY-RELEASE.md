# Identity Atlas PowerShell Gallery release procedure

Date: 4 August 2026

Target Gallery version: `0.15.1-preview1`

Matching GitHub version: `v0.15.1-preview.1`

Publisher: Control Alt Delete Tech Bits

## Current status

1. The `IdentityAtlas` package name is available at the time of preparation.
2. The Gallery manifest metadata passes its source gate.
3. The matching GitHub ZIP and Gallery NuGet package build locally.
4. The PowerShell, JavaScript, release security and Gallery package tests pass.
5. No package has been submitted to the PowerShell Gallery.
6. A publisher account and privately handled API key are still required.

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
    -ReleasePath .\Release\IdentityAtlas-v0.15.1-preview.1.zip
```

Build the Gallery package from that exact release archive:

```powershell
.\tools\New-IdentityAtlasGalleryPackage.ps1 `
    -OutputPath .\Gallery `
    -ReleasePath .\Release\IdentityAtlas-v0.15.1-preview.1.zip
```

Run the Gallery package gate independently:

```powershell
.\tools\Test-IdentityAtlasGalleryPackage.ps1 `
    -PackagePath .\Gallery\IdentityAtlas.0.15.1-preview1.nupkg
```

## Publication order

1. Merge the tested changes to `main` through the protected pull request process.
2. Confirm the GitHub validation workflow passes.
3. Rebuild both packages from the final `main` commit.
4. Run the complete Git history and package security gate.
5. Create the immutable `v0.15.1-preview.1` Git tag.
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
        -Nupkg .\Gallery\IdentityAtlas.0.15.1-preview1.nupkg `
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
4. Confirm the Gallery displays `0.15.1-preview1` as a prerelease.
5. Find the package from a clean PowerShell 7 session.
6. Install it into an isolated current-user test environment.
7. Confirm all four Identity Atlas commands are exported.
8. Run a Core collection against the authorised development tenant.
9. Confirm the report remains local and contains no fixture data.
10. Record the published package URL, publication date and validation evidence in the project log.

Discovery and installation commands:

```powershell
Find-PSResource IdentityAtlas -Version 0.15.1-preview1 -Prerelease -Repository PSGallery

Install-PSResource IdentityAtlas `
    -Version 0.15.1-preview1 `
    -Prerelease `
    -Scope CurrentUser `
    -TrustRepository
```

## Publication boundary

The initial Gallery release is manual. GitHub Actions has read-only repository permissions and contains no PowerShell Gallery API key. Automated publishing can be considered only after the manual process has been proven and a separately reviewed secret-handling design is approved.
