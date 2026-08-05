# Identity Atlas v1.0.0

Release date: 5 August 2026

Publisher: Control Alt Delete Tech Bits

Identity Atlas 1.0.0 is the first stable release of the local, read-only Microsoft Entra relationship explorer.

## Security changes

1. Comparison reports no longer embed tenant data inside an inline browser script.
2. Comparison data and application logic are separate local resources protected by a restrictive Content Security Policy.
3. Hostile tenant strings are covered by automated script-injection regression tests.
4. `Connect-IdentityAtlas` accepts optional dedicated `ClientId` and `TenantId` values for an isolated Microsoft Graph consent boundary.
5. Settings includes a two-step control for clearing Identity Atlas pins, review states and layout preferences from browser storage.

The main interactive report was not affected by the comparison issue. Version 0.16.0-preview.1 users should upgrade before opening newly generated comparison HTML.

## Stable capabilities

1. Local collection through delegated Microsoft Graph read permissions.
2. Users, groups, nested memberships, applications, service principals, devices and authentication methods.
3. Directory roles, active and eligible role assignments, and PIM for Groups.
4. Conditional Access policies, named locations and authentication strengths.
5. Cross-tenant access, application management policies and Administrative Units.
6. Entitlement Management and Access Reviews.
7. Evidence-backed access paths with confidence and collection coverage.
8. Permission blast radius, security insights, action plans and review states.
9. Timeline, report comparison and JSON, CSV, Markdown, Mermaid, SVG and PNG exports.
10. Offline single-page report served only on the local loopback interface.

## Install from PowerShell Gallery

```powershell
Install-PSResource IdentityAtlas -Scope CurrentUser -TrustRepository
Import-Module IdentityAtlas
```

PowerShellGet users can run:

```powershell
Install-Module IdentityAtlas -Scope CurrentUser
Import-Module IdentityAtlas
```

## Run

```powershell
Connect-IdentityAtlas -UseDeviceCode -ContextScope Process
Invoke-IdentityAtlas `
    -OutputPath "$env:USERPROFILE\Documents\IdentityAtlas-$(Get-Date -Format 'yyyyMMdd-HHmmss')" `
    -OpenReport
```

Use the Governance profile when its additional read permissions and licensed Microsoft Entra features are required.

## Upgrade

```powershell
Update-PSResource IdentityAtlas -Scope CurrentUser
```

PowerShellGet users can run:

```powershell
Update-Module IdentityAtlas
```

Close existing PowerShell sessions before upgrading if Microsoft Graph modules are loaded.

## Data handling

Identity Atlas reports contain administrative evidence and are not encrypted. Keep reports in an access-controlled folder, stop the local report server after use, disconnect Microsoft Graph and delete reports according to organisational retention requirements.
