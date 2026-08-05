# Identity Atlas

Identity Atlas is a local, read-only visual explorer for Microsoft Entra objects, relationships and access paths.

Publisher: Control Alt Delete Tech Bits

Lead maintainer: Mark Oldham

Current stable release: 1.0.0

PowerShell Gallery version: 1.0.0

PowerShell Gallery: https://www.powershellgallery.com/packages/IdentityAtlas/1.0.0

Identity Atlas is an independent community project. It is not a Microsoft product and is not affiliated with, endorsed by or sponsored by Microsoft.

## Purpose

Identity Atlas helps Microsoft Entra administrators understand how identity, application, role, policy and permission objects relate to each other. PowerShell collects and serialises read-only Microsoft Graph evidence. The generated browser report performs filtering, searching, graph expansion and navigation locally.

Generated reports contain sensitive administrative evidence. They are intended for an authorised administrator’s local device and must not be published.

## Stable release capabilities

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
17. Nested group paths with intermediate groups retained as evidence-backed relationships.
18. Cross-tenant access policy and partner-tenant visualisation.
19. Default and targeted application management policy coverage.
20. An optional Governance profile covering Administrative Units, PIM for Groups, Entitlement Management and Access Reviews.

## Requirements

1. PowerShell 7 or later.
2. A current Chromium-based browser.
3. Microsoft Graph PowerShell authentication module.
4. An account that can consent to or use the documented delegated read permissions.
5. Local storage suitable for sensitive administrative evidence.

Node.js and Pester 5.7.1 are needed only for development and contribution testing.

## Install from PowerShell Gallery

PowerShell 7 users can install Identity Atlas and its Microsoft Graph authentication dependency with:

```powershell
Install-PSResource IdentityAtlas -Scope CurrentUser -TrustRepository
Import-Module IdentityAtlas
```

PowerShellGet users can use:

```powershell
Install-Module -Name IdentityAtlas -Scope CurrentUser
Import-Module IdentityAtlas
```

The published Gallery package was downloaded after publication and matched the locally tested package SHA256 exactly.

Maintainer publication procedure: https://github.com/ControlAltDeleteTechBits/identity-atlas/blob/main/Docs/POWERSHELL-GALLERY-RELEASE.md

## Inspect or run from the GitHub source release

Current release: https://github.com/ControlAltDeleteTechBits/identity-atlas/releases/tag/v1.0.0

The immutable GitHub `v1.0.0` release contains GitHub's automatic source archives. It does not contain the separately packaged module ZIP. Use PowerShell Gallery for the supported installation route above.

To inspect or run the repository source instead:

1. Download GitHub's `Source code (zip)` archive.
2. Extract it into an access-controlled location.
3. Install the Microsoft Graph authentication dependency.
4. Import `IdentityAtlas.psd1` from the extracted repository root.

```powershell
Install-PSResource Microsoft.Graph.Authentication -Scope CurrentUser -TrustRepository
Import-Module .\IdentityAtlas.psd1 -Force
```

## Run against a tenant

The live collectors require the Microsoft Graph PowerShell authentication module.

```powershell
Install-PSResource Microsoft.Graph.Authentication -Scope CurrentUser
Import-Module IdentityAtlas
Connect-IdentityAtlas -UseDeviceCode
Invoke-IdentityAtlas -OutputPath .\Output\DevTenant -OpenReport
```

For a strict least privilege consent boundary, use a dedicated Microsoft Entra application registration:

```powershell
Connect-IdentityAtlas `
    -UseDeviceCode `
    -ClientId '<application-client-id>' `
    -TenantId '<directory-tenant-id>' `
    -ContextScope Process
```

Setup guidance: https://github.com/ControlAltDeleteTechBits/identity-atlas/blob/main/Docs/DEDICATED-GRAPH-APPLICATION.md

During collection, PowerShell shows the active collector, elapsed time, Graph request and retry totals, collected object, relationship and evidence counts, and current item progress. `-OpenReport` starts a loopback-only server, selects port 8766 or the next available permitted port, then opens the interactive report in the default browser. The result object includes `ReportUrl` and `ServerProcessId` so the session can be checked or stopped later.

The slower per-object collectors use Microsoft Graph JSON batches of ten GET requests by default. Set a smaller limit when required:

```powershell
Invoke-IdentityAtlas -OutputPath .\Output\DevTenant -OpenReport -BatchSize 5
```

For a faster, deliberately reduced collection, skip every slower per-object collector:

```powershell
Invoke-IdentityAtlas -OutputPath .\Output\DevTenant -OpenReport -SkipSlowCollectors
```

The generated report is marked as partial and records which collectors were skipped. Individual options are `GroupMembersAndOwners`, `DeviceOwners`, `AuthenticationMethods`, `ApplicationRoleAssignments` and `ApplicationOwners`:

```powershell
Invoke-IdentityAtlas `
    -OutputPath .\Output\DevTenant `
    -OpenReport `
    -SkipCollector AuthenticationMethods,ApplicationOwners
```

Press Ctrl+C to cancel an active collection. Identity Atlas prints a cancellation summary containing the elapsed time, completed collector count, request and retry totals, and the object, relationship and evidence totals collected before cancellation. A cancelled run does not write an incomplete report package.

If `-OpenReport` is omitted, the report is written without starting a server. A repository checkout can still start it manually with:

```powershell
.\tools\Start-IdentityAtlasDevServer.ps1 -Root .\Output\DevTenant -Port 8766
```

The Core profile remains the default and requests only the original delegated read permissions. To include Identity Governance data, use the explicit Governance profile for both connection and collection:

```powershell
Connect-IdentityAtlas -UseDeviceCode -CollectionProfile Governance
Invoke-IdentityAtlas -CollectionProfile Governance -OutputPath .\Output\DevTenant -OpenReport
```

The Governance profile adds these delegated read permissions:

```text
AdministrativeUnit.Read.All
PrivilegedAssignmentSchedule.Read.AzureADGroup
PrivilegedEligibilitySchedule.Read.AzureADGroup
EntitlementManagement.Read.All
AccessReview.Read.All
```

Microsoft Entra licensing and a supported signed-in administrator role can still be required before Graph returns PIM, Entitlement Management or Access Review data. A denied or unavailable collector is recorded as partial coverage rather than being hidden.

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
5. Use Settings, Clear Identity Atlas browser data, when reviewing a report on a shared device.

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
User > nested group chain > application app role or Conditional Access policy inclusion
User > eligible directory role
User > registered device
User > authentication method
User > active or eligible PIM group membership or ownership
User > access package > governed resource role
User or group > Administrative Unit membership or scoped administration
Resource > Access Review definition > review instance and decision evidence
Application > owner
Application > credential
Application > required API permission
Application registration > enterprise application
Conditional Access policy > named location
Conditional Access policy > authentication strength
Application > application management policy
Cross-tenant access default > partner tenant configuration
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

The access worker traverses supported nested group chains up to eight relationships while preventing loops. Microsoft Entra role-assignable groups remain direct-only because role-assignable group nesting is not supported by the platform.

## Contributing

Community contributions are welcome through GitHub issues and reviewed pull requests. Direct write access is not required.

Start with `CONTRIBUTING.md` and `CODE_OF_CONDUCT.md`. Never include live tenant data, generated reports, credentials or confidential screenshots in a contribution.

Control Alt Delete Tech Bits remains the project publisher. Mark Oldham reviews proposed changes and retains final responsibility for project scope, Microsoft Graph permissions, security boundaries and releases.

## Licence

Identity Atlas is released under the MIT Licence. See `LICENSE`.

Selected Tabler Icons assets retain their own MIT notice in `Web/assets/icons/TABLER-LICENSE.txt`. See `THIRD-PARTY-NOTICES.md`.
