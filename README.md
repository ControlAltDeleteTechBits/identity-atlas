# Identity Atlas

Identity Atlas is a local, read-only visual explorer for Microsoft Entra objects, relationships and access paths.

Publisher: Control Alt Delete Tech Bits

Lead maintainer: Mark Oldham

Current release: 0.14.0 preview

Identity Atlas is an independent community project. It is not a Microsoft product and is not affiliated with, endorsed by or sponsored by Microsoft.

## Purpose

Identity Atlas helps Microsoft Entra administrators understand how identity, application, role, policy and permission objects relate to each other. PowerShell collects and serialises read-only Microsoft Graph evidence. The generated browser report performs filtering, searching, graph expansion and navigation locally.

Generated reports contain sensitive administrative evidence. They are intended for an authorised administrator’s local device and must not be published.

## Community preview

1. Canonical node, edge, evidence and report-manifest contracts.
2. PowerShell collectors for users, groups, direct group memberships, group owners, app registrations, service principals, application owners, credential summaries, required API permissions, app role assignments, devices, registered device owners, user authentication methods, Conditional Access policies, named locations, authentication strengths, directory role definitions, active role assignments and eligible role assignments.
3. An internal deterministic fixture used only by automated tests.
4. An offline HTML, CSS and JavaScript report.
5. Client-side search, filtering, relationship filtering, object details and focused graph views.
6. Evidence-backed user and application access explanations for roles, app roles, credentials, owners, API permissions and Conditional Access policy inclusion.
7. Local Mermaid, SVG, PNG and evidence Markdown export for the visible graph or selected path.
8. Admin insight checks with severity, action plans, review states and per-finding evidence export.
9. JSON, CSV and Markdown report export.
10. Report comparison with JSON, Markdown and offline HTML output.
11. A compact three-panel explorer influenced by the Redact Ninja product shell.
12. Settings view with support email, donation link and evidence-first layout mode.
13. Change timeline inside the main report.
14. Coverage confidence on access paths.
15. Permission blast radius and Conditional Access impact panels.
16. Stale device and weak authentication method hygiene checks.

## Requirements

1. PowerShell 7 or later.
2. A current Chromium-based browser.
3. Microsoft Graph PowerShell authentication module.
4. An account that can consent to or use the documented delegated read permissions.
5. Local storage suitable for sensitive administrative evidence.

Node.js and Pester 5.7.1 are needed only for development and contribution testing.

## Install from a release

1. Download the versioned ZIP and matching SHA256 file from GitHub Releases.
2. Verify the checksum before extracting the ZIP.
3. Extract the `IdentityAtlas` folder into an access-controlled location.
4. Import `IdentityAtlas.psd1`.

Example checksum verification:

```powershell
$expected = (Get-Content .\IdentityAtlas-v0.14.0-preview.1-SHA256.txt).Split(' ')[0]
$actual = (Get-FileHash .\IdentityAtlas-v0.14.0-preview.1.zip -Algorithm SHA256).Hash
if ($actual -ne $expected) {
    throw 'The downloaded Identity Atlas archive does not match its published checksum.'
}
```

## Run against a tenant

The live collectors require the Microsoft Graph PowerShell authentication module.

```powershell
Install-PSResource Microsoft.Graph.Authentication -Scope CurrentUser
Import-Module .\IdentityAtlas.psd1
Connect-IdentityAtlas -UseDeviceCode
Invoke-IdentityAtlas -OutputPath .\Output\DevTenant -OpenReport
.\tools\Start-IdentityAtlasDevServer.ps1 -Root .\Output\DevTenant -Port 8766
```

Normal admin use should always open `.\Output\DevTenant` or another live tenant export. Synthetic fixture data is confined to automated tests, generated in a temporary directory and removed when the tests finish. The development server always refuses fixture data.

`Connect-IdentityAtlas` uses a process scoped Microsoft Graph context by default. Use `-ContextScope CurrentUser` only when a persistent sign in is intentional. Run `Disconnect-MgGraph` when collection is complete.

Node.js is used only for development tests. Generated live tenant reports do not require it.

The initial delegated scopes are:

```text
User.Read.All
UserAuthenticationMethod.Read.All
Group.Read.All
Device.Read.All
Application.Read.All
Policy.Read.All
RoleEligibilitySchedule.Read.Directory
RoleManagement.Read.Directory
```

No Microsoft Graph write permission is requested.

## Security and report handling

Live reports contain administrative evidence, including tenant identifiers, user principal names, role assignments, application metadata, policy relationships and device posture.

1. Store reports and exports in an access controlled folder.
2. Do not publish live reports or commit them to source control.
3. Stop the local server when review is complete.
4. Delete reports according to the organisation's evidence retention policy.
5. Clear browser site data on shared devices because pins and review states are tenant specific and persistent.

The report does not contain Microsoft Graph access tokens, passwords, client secret values or certificate material. The local server binds only to `127.0.0.1`, requires a valid Identity Atlas package marker and refuses sample fixture data.

See `SECURITY.md` and `Docs/SECURITY-REVIEW.md` for the reporting process, threat review, permission assessment and residual risks.

If Microsoft Graph omits a referenced object, collection continues and the
report is marked as partial. The warning remains available in the generated
report so that incomplete evidence is not presented as complete.

## Design boundary

PowerShell authenticates, collects, normalises, validates and serialises. The browser performs search, filtering, navigation, relationship expansion and access-path traversal after the report opens.

The current access explanation rule supports:

```text
User > active directory role
User > direct role-assignable group > active directory role
User > application app role
User > direct group > application app role
User > Conditional Access policy inclusion
User > direct group > Conditional Access policy inclusion
User > eligible directory role
User > registered device
User > authentication method
Application > owner
Application > credential
Application > required API permission
Application registration > enterprise application
Conditional Access policy > named location
Conditional Access policy > authentication strength
```

## Compare two reports

```powershell
Compare-IdentityAtlas -ReferenceReportPath .\Output\LastMonth -DifferenceReportPath .\Output\ThisMonth -OutputPath .\Output\Comparison
```

The comparison output includes added, removed and changed objects and relationships. When `-OutputPath` is provided it writes `comparison.json`, `comparison.md` and `comparison.html`.

## Support and donations

```text
Support: Mark@controlaltdeletetechbits.co.uk
Repository: https://github.com/ControlAltDeleteTechBits/identity-atlas
Donate: https://buymeacoffee.com/cadtb
```

## Export a report summary

```powershell
$report = Get-Content -Raw .\Output\DevTenant\data\report.json | ConvertFrom-Json
Export-IdentityAtlas -InputObject $report -OutputPath .\Output\Exports -Format Markdown
Export-IdentityAtlas -InputObject $report -OutputPath .\Output\Exports -Format Csv
```

It does not traverse nested groups for directory-role access because active group nesting is not supported for role-assignable groups.

## Contributing

Community contributions are welcome through GitHub issues and reviewed pull requests. Direct write access is not required.

Start with `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md`. Never include live tenant data, generated reports, credentials or confidential screenshots in a contribution.

Control Alt Delete Tech Bits remains the project publisher. Mark Oldham reviews proposed changes and retains final responsibility for project scope, Microsoft Graph permissions, security boundaries and releases.

## Licence

Identity Atlas is released under the MIT Licence. See `LICENSE`.

Selected Tabler Icons assets retain their own MIT notice in `Web/assets/icons/TABLER-LICENSE.txt`. See `THIRD-PARTY-NOTICES.md`.
