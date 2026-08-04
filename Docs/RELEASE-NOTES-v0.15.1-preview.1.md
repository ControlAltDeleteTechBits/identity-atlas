# Identity Atlas v0.15.1 preview 1

Release status: PowerShell Gallery release candidate

## Summary

Identity Atlas v0.15.1 prepares the existing Microsoft Entra relationship explorer for its first PowerShell Gallery publication. The application features and delegated Microsoft Graph permission boundary remain unchanged from v0.15.0.

## Installation improvements

1. Microsoft.Graph.Authentication 2.38.1 or later is now a declared module dependency.
2. PowerShell Gallery installations can acquire the Graph authentication dependency automatically.
3. The module declares PowerShell Core compatibility and PowerShell 7 as its minimum version.
4. Gallery metadata includes the approved Identity Atlas branding, project link, MIT Licence link, tags and release notes.

After Gallery publication, install the preview with:

```powershell
Install-PSResource IdentityAtlas -Prerelease -Scope CurrentUser -TrustRepository
Import-Module IdentityAtlas
```

## Package integrity

1. The Gallery package is built from the matching checksummed GitHub release archive.
2. The NuGet package receives its own SHA256 checksum.
3. The package gate checks metadata, dependencies, archive contents, tenant-data and secret patterns, module validity and clean import.
4. The package contains no tenant report, automated-test fixture, release output, Git metadata or publisher credential.

## Permission boundary

Identity Atlas continues to request delegated, read-only Microsoft Graph permissions. The Core profile remains the default. Governance collection remains explicit and optional. No Microsoft Graph write permission has been added.

## Publication status

This candidate has not yet been published to the PowerShell Gallery. Publication requires a Control Alt Delete Tech Bits publisher account and a privately handled Gallery API key.
