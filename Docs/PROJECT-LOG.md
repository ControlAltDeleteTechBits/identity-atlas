# Identity Atlas project log and roadmap

Date: 29 July 2026

Owner: Mark Oldham

Implementation status: v0.14.0 Identity Atlas preview

## Current goal

Build Identity Atlas as a local, read-only Microsoft Entra relationship explorer. PowerShell collects and serialises Microsoft Graph data. The browser performs search, filtering, graph expansion, object inspection and access explanation locally.

The project now has a working offline SPA, a common graph object model and live collectors for core identity, application, role, device and Conditional Access resources. Synthetic data is retained only as an internal automated-test fixture.

## Progress

1. v0.1.0 established the base PowerShell module, graph contracts, sample report generation and offline HTML viewer.
2. v0.2.0 rebuilt the interface as a compact three-panel explorer influenced by the Redact Ninja product shell.
3. v0.3.0 added enterprise applications through service principal nodes and app role assignment relationships.
4. v0.4.0 added Conditional Access policy nodes and policy inclusion or exclusion relationships.
5. v0.5.0 added application registrations, owners, credential summary nodes, required API permissions and app ownership evidence.
6. v0.6.0 added eligible role assignments, admin insights, report comparison, Markdown evidence export, Mermaid export and JSON, CSV or Markdown report export.
7. v0.7.0 added devices, registered device owners, user authentication methods, Conditional Access named locations and authentication strengths.
8. v0.8.0 added changed-object and changed-relationship detection to report comparison, plus an offline comparison HTML view.
9. v0.9.0 added browser-side SVG export for the visible graph.
10. v0.10.0 added PNG export, a working Settings view, direct support email, a donation link and browser search performance hardening.
11. v0.11.0 added severity-driven Insights, per-finding evidence export, admin review states, a report timeline, evidence-first layout, access-path confidence, remediation PowerShell snippets, permission blast radius, Conditional Access impact simulation and stale device or weak authentication hygiene checks.
12. v0.11.1 added tenant-only serving safeguards so sample fixture reports are blocked by the dev server unless explicitly allowed.
13. v0.11.2 completed dev-tenant validation and hardened collectors for scalar application collections, null Conditional Access references and invalid graph records.
14. v0.12.0 added relationship grouping, clickable object-history breadcrumbs, tenant-persistent pinned objects and actionable coverage diagnostics.
15. v0.13.0 completed the first release-hardening phase for permissions, token and tenant data safety, partial collection, report writing and loopback serving.
16. v0.14.0 renamed the product and technical package to Identity Atlas before public release, while keeping Microsoft Entra ID references only where they describe the supported platform.

## Changes in v0.14.0

1. Renamed the public product from the previous working name to Identity Atlas.
2. Renamed the PowerShell module to `IdentityAtlas`.
3. Renamed the public commands to `Connect-IdentityAtlas`, `Invoke-IdentityAtlas`, `Export-IdentityAtlas` and `Compare-IdentityAtlas`.
4. Renamed the module manifest, root module, public command files, test file and development-server script.
5. Renamed browser globals, export filenames, storage keys, report-package markers and schema identifiers.
6. Rebuilt the approved Space Grotesk wordmark so `IDENTITY` replaces the previous product word while retaining the selected `ATLAS` treatment and globe.
7. Added Identity Atlas accessible names to the browser title, header logo and globe mark.
8. Updated the module and report version to `0.14.0`.
9. Updated the report-package format to `IdentityAtlasReport` package version `2.0.0`.
10. Removed the public `SampleData` collection switch so `Invoke-IdentityAtlas` always requires a live Microsoft Graph tenant context.
11. Moved synthetic fixture creation out of the production module and into the automated-test area.
12. Changed worker tests to create their fixture report in the system temporary directory and remove it after testing.
13. Changed the local server to reject fixture reports without an override.
14. Removed obsolete generated fixture and comparison reports from `Output`; only the live tenant report remains.
15. Upgraded the retained live tenant report to the Identity Atlas 0.14.0 package without changing its 498 objects, 120 relationships or 120 evidence records.
16. Increased the PowerShell test suite to 34 passing tests and retained eight passing JavaScript worker tests.
17. Renamed the project directory from its internal working name to `IdentityAtlas`.
18. Browser-tested the wordmark, Applications view, Settings view, live report counts and package origin with no console errors.

## Changes in v0.13.0

1. Added delegated scope assessment after Microsoft Graph authentication.
2. Recognised documented higher privilege alternatives without requesting them by default.
3. Added a permission preflight collector so missing scope coverage is visible in the report.
4. Added a protected top level collector boundary so one failed resource type no longer ends the whole report.
5. Sanitised collector errors before adding them to tenant report warnings.
6. Redacted bearer values and common authentication query parameters from error details.
7. Restricted relative and paginated Graph requests to recognised API paths and Microsoft Graph cloud hosts.
8. Expanded bounded retry handling to HTTP 429, 502, 503 and 504.
9. Added request duration metrics.
10. Added schema 1.1.0 security metadata confirming read only collection, no serialised tokens, disabled browser network access and loopback serving.
11. Added atomic writes for generated JSON and JavaScript data files.
12. Prevented report output from targeting filesystem roots, the project root or source directories.
13. Added an Identity Atlas report package marker containing version, origin and generation details.
14. Required the local server to validate the index, manifest and package marker before serving.
15. Required package and manifest origins to match.
16. Kept sample fixture reports blocked unless explicitly allowed.
17. Fixed report-root containment so similarly named sibling folders cannot be served.
18. Added GET and HEAD handling, request size limits, client timeouts and restrictive response security headers.
19. Tightened the browser Content Security Policy and added a no-referrer policy.
20. Added a Security and data handling section to Settings.
21. Added `SECURITY.md` and a detailed `Docs/SECURITY-REVIEW.md`.
22. Changed the recommended one-off sign-in workflow to process scoped authentication.
23. Increased the PowerShell test suite from 22 to 33 passing tests.
24. Upgraded the existing 498 object live report to the v0.13.0 package format without changing its tenant data.
25. Restarted the live report on port 8766 with the hardened loopback server.

## Changes in v0.12.0

1. Added relationship groups for roles, policies, applications, groups, devices, authentication methods, identities and other objects.
2. Added group count buttons that can show or hide each relationship category without changing the collected report data.
3. Increased the focused neighbour view from 12 relationships to a balanced maximum of 24 visible relationships.
4. Added full and visible relationship counts so a truncated graph does not imply complete coverage.
5. Added clickable object-history breadcrumbs while retaining the named Back control.
6. Limited the breadcrumb trail to the six most recent objects to keep the inspector readable.
7. Added Pin object and Unpin object controls.
8. Added a pinned-object panel above search results.
9. Stored pins per tenant so they survive report regeneration but do not cross tenant boundaries.
10. Added collector summary cards and status badges to the coverage inspector.
11. Converted raw coverage warnings into diagnostic cards with Graph endpoints, permissions or role checks, coverage effects and PowerShell retry commands.
12. Added an Open affected object action when a warning can be matched to a collected object.
13. Added the `relationshipGrouping`, `objectBreadcrumbs`, `pinnedObjects` and `coverageDiagnostics` report capabilities.
14. Updated the module and report version to `0.12.0`.
15. Regenerated the development-tenant report from Microsoft Graph at 13:14 UTC with the `LiveTenant` data origin.
16. Browser-tested relationship group filtering, breadcrumb restoration, pin persistence, pin removal and both live coverage diagnostics.
17. Confirmed there were no browser console errors after the final live report refresh.
18. Integrated the approved Identity Atlas Space Grotesk wordmark and cartographic globe into the utility header.
19. Added a matching globe-only SVG browser icon and retained an accessible Identity Atlas page heading.
20. Kept both brand assets local and self-contained so exported reports do not depend on web fonts or external services.

## Changes in v0.11.2

1. Completed Microsoft Graph device-code authentication against the development tenant.
2. Generated and browser-tested a live report containing 498 objects, 120 relationships and 120 evidence records.
3. Fixed application registration collection when Microsoft Graph returns a single credential or required-resource-access object instead of an array.
4. Made Graph property extraction null-safe for optional Conditional Access objects.
5. Added merge validation so malformed nodes, relationships or evidence records cannot corrupt the final report.
6. Added regression tests for scalar application collections and policies without authentication-strength references.
7. Verified Applications, Roles, Settings and access explanation against live tenant data.
8. Confirmed the live report is tagged `LiveTenant` and contains no sample fixture data.
9. Confirmed there are no browser console errors.
10. Updated the PowerShell test result to 22 passed and 0 failed.
11. Updated the module and report version to `0.11.2`.
12. Replaced the compressed single-column relationship graph with a spaced two-column layout for larger neighbour sets.
13. Added object-selection history and a named Back control such as `Back to CADTB`.
14. Reset graph and inspector scroll positions when the selection changes.
15. Added long-title wrapping and object-type-aware inspector descriptions.
16. Reproduced and browser-tested the CADTB > Windows Hello for Business > CADTB flow at 1848 by 889 pixels with no console errors.

## Changes in v0.11.1

1. Added manifest data origin tagging so live tenant reports are marked `LiveTenant` and internal fixtures are marked `SampleFixture`.
2. Updated the local dev server to refuse sample fixture reports unless `-AllowSampleData` is passed explicitly.
3. Stopped the old local `8766` server that was serving `Output\Sample`.
4. Updated README tenant-run instructions so normal use serves `.\Output\DevTenant`.
5. Attempted two Microsoft Graph device-code sign-ins, both of which timed out before a tenant context was returned.
6. Updated the module and report version to `0.11.1`.

## Changes in v0.11.0

1. Added severity levels to Insights: Critical, High, Medium and Low.
2. Added why-it-matters and action-plan text to every Insight check.
3. Added per-finding Markdown evidence export from the Insights view.
4. Added persisted admin review states: New, Reviewed, Accepted risk, Needs change and False positive.
5. Added remediation PowerShell snippets for each Insight result.
6. Added a Timeline view for report generation, credential expiry, device last sign-in, object created or modified dates and PIM eligibility end dates.
7. Added coverage confidence badges to access paths.
8. Added an evidence-first layout mode in Settings.
9. Added permission blast radius panels for API permissions, applications, directory roles and Conditional Access policies.
10. Added Conditional Access impact panels for users, groups, applications, service principals and policies.
11. Added stale device and privileged-user weak authentication hygiene checks.
12. Fixed the single search result stretching vertically in the results list.
13. Browser-tested the sample report and a large synthetic report with no console errors.
14. Updated the module and report version to `0.11.0`.

## Changes in v0.10.0

1. Added PNG export for the visible graph.
2. Fixed the sidebar Settings button by adding a real Settings view.
3. Wired the graph settings icon to the same Settings view.
4. Removed the local-processing footer card from the navigation.
5. Replaced the Redact Ninja support link with `mailto:Mark@controlaltdeletetechbits.co.uk`.
6. Added a Donate navigation item pointing to `https://buymeacoffee.com/cadtb`.
7. Added precomputed worker search text to reduce repeated string work on larger reports.
8. Added debounced search input and stale-result protection in the SPA.
9. Updated the CSP image directive to allow Blob-backed PNG rendering while keeping network connections disabled.
10. Updated the module and report version to `0.10.0`.

## Changes in v0.9.0

1. Added an SVG export button to the graph toolbar.
2. Added client-side SVG serialisation for the currently visible graph.
3. Embedded export-specific SVG styling so exported diagrams remain readable outside the app.
4. Browser-tested the SVG export button state with no console errors.
5. Updated the module and report version to `0.9.0`.

## Changes in v0.8.0

1. Updated `Compare-IdentityAtlas` to detect changed objects and changed relationships.
2. Ignored volatile collection timestamps during comparison so unchanged objects are not reported as changed.
3. Added changed object and changed relationship counts to `comparison.json` and `comparison.md`.
4. Added `comparison.html`, an offline browser view for added, removed and changed objects or relationships.
5. Added a test that changes a Conditional Access policy state and verifies the changed-object result.
6. Browser-tested the generated comparison view with no console errors.
7. Updated the module and report version to `0.8.0`.

## Changes in v0.7.0

1. Added `Get-AtlasDeviceAndAuthentication`.
2. Added `Get-AtlasConditionalAccessReference`.
3. Added `Device.Read.All` and `UserAuthenticationMethod.Read.All` to the default delegated read scopes.
4. Added `device`, `authenticationMethod`, `namedLocation` and `authenticationStrength` graph nodes.
5. Added `registeredDevice`, `hasAuthenticationMethod`, `conditionalAccessIncludesLocation`, `conditionalAccessExcludesLocation` and `requiresAuthenticationStrength` relationships.
6. Updated the browser labels, object filters, icons, relationship names and admin insight checks for the new objects.
7. Updated the worker so the access explorer can include device and authentication method context for users.
8. Updated the sample fixture with one registered device, one Microsoft Authenticator method, one trusted named location and one authentication strength.
9. Updated the module and report version to `0.7.0`.

## Current graph coverage

1. Users.
2. Guest users.
3. Groups.
4. Direct group membership.
5. Directory role definitions.
6. Active directory role assignments.
7. Service principals.
8. App role assignments.
9. Conditional Access policies.
10. Conditional Access user, group and application inclusion.
11. Conditional Access user, group and application exclusion.
12. Application registrations.
13. Application and service principal owners.
14. Application credential summaries.
15. Required API permissions.
16. PIM eligible directory role assignments.
17. Devices.
18. Registered device owner relationships.
19. User authentication methods.
20. Conditional Access named locations.
21. Conditional Access authentication strengths.
22. Evidence records for every collected relationship.

## Current access explanation coverage

The browser can currently trace:

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
```

Exclusions are collected and visible as relationships, but the path explainer does not yet treat an exclusion as a positive access path. That is deliberate because an exclusion explains why a control may not apply, not why access was granted.

## Verification

Latest local build result:

```text
PowerShell Pester tests: 41 passed, 0 failed
JavaScript worker tests: 8 passed, 0 failed
Browser smoke test: passed for the isolated test fixture, Settings view, SVG and PNG export controls and comparison view with no new console errors
Browser v0.11.2 live-tenant smoke test: passed for Applications, Roles, Settings, access explanation, readable multi-relationship graphs and object Back navigation with no console errors
Browser v0.12.0 live-tenant smoke test: passed for relationship group filtering, breadcrumbs, tenant-persistent pins, pin removal and actionable coverage diagnostics with no console errors
Browser v0.13.0 live-tenant smoke test: passed for hardened package loading, Settings security guidance and console validation
Browser v0.14.0 live-tenant smoke test: passed for the Identity Atlas wordmark, Applications, Settings, live report counts, package origin and console validation
Hardened server tests: GET 200, HEAD 200, POST 405, sibling traversal 403, test-fixture report blocked and incomplete package blocked
Large synthetic browser test: passed with 2,560 nodes, 3,360 relationships and 3,360 evidence records
Test fixture nodes: 16
Test fixture edges: 21
Test fixture evidence records: 21
```

Static PowerShell analysis passed during the build.

## Live tenant validation status

Live validation completed on 28 July 2026 against a development tenant. On 29 July 2026, the existing live data was upgraded to the Identity Atlas v0.14.0 package format. The tenant identifier has been removed from this public project record. The tenant was not recollected because no reusable Microsoft Graph PowerShell context was available.

The report retained the expected live object, relationship and evidence counts. Its data origin was `LiveTenant` and its coverage status was partial.

Two Graph coverage warnings remain:

1. Authentication methods for one user returned `403 Forbidden`.
2. One role assignment referenced a role definition that Graph did not return.

These warnings are displayed as actionable coverage diagnostics and do not prevent the rest of the tenant report from loading.

The validated PowerShell 7 workflow is:

```powershell
Import-Module .\IdentityAtlas.psd1 -Force
Connect-IdentityAtlas -UseDeviceCode
Invoke-IdentityAtlas -OutputPath .\Output\DevTenant -OpenReport
.\tools\Start-IdentityAtlasDevServer.ps1 -Root .\Output\DevTenant -Port 8766
Disconnect-MgGraph
```

Required delegated read scopes:

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

If persistent authentication is required, add `-ContextScope CurrentUser`. Process scope is preferred for one-off reviews.

If a delegated read scope is not granted, the permission preflight and affected collector are marked as partial rather than failing the whole report.

## Microsoft Graph references

1. Conditional Access policies: https://learn.microsoft.com/en-us/graph/api/conditionalaccessroot-list-policies?view=graph-rest-1.0
2. Service principals: https://learn.microsoft.com/en-us/graph/api/serviceprincipal-list?view=graph-rest-1.0
3. App role assignments granted for a service principal: https://learn.microsoft.com/en-us/graph/api/serviceprincipal-list-approleassignedto?view=graph-rest-1.0
4. Devices: https://learn.microsoft.com/en-us/graph/api/device-list?view=graph-rest-1.0
5. User authentication methods: https://learn.microsoft.com/en-us/graph/api/authentication-list-methods?view=graph-rest-1.0
6. Conditional Access named locations: https://learn.microsoft.com/en-us/graph/api/conditionalaccessroot-list-namedlocations?view=graph-rest-1.0
7. Authentication strength policies: https://learn.microsoft.com/en-us/graph/api/authenticationstrengthroot-list-policies?view=graph-rest-1.0

## Known gaps

1. Nested group traversal is not implemented.
2. Role-assignable group nesting is still deliberately treated as unsupported for role paths.
3. Conditional Access exclusions are visible as relationships, but the path explainer does not treat exclusions as positive access paths.
4. Device ownership and authentication methods are collected as context; deeper sign-in risk, device compliance policy and Intune relationships are not implemented.
5. The Timeline view is implemented for a single report, but comparison timeline rendering is still separate future work.
6. One user authentication-method endpoint returned `403 Forbidden` during live validation.
7. One live role assignment referenced a role definition that Graph did not return.

## Estimated remaining work

These estimates assume one developer, a dev tenant with consent available and no major Microsoft Graph throttling.

1. Phase 8, comparison timeline in the browser: 1 to 2 days.
2. Phase 10, larger-tenant performance pass beyond the current synthetic smoke test: 1 to 3 days.
3. Phase 11, deeper device and sign-in context: 2 to 4 days.
4. Phase 12, packaging and release hardening: 1 to 2 days.

Expected time to a stronger v0.8 preview: 2 to 4 focused working days.

Expected time to a strong v1.0 candidate: 3 to 5 weeks, depending on live tenant testing coverage and how broad the first supported object set should be.

## Roadmap

### Phase 8: Change comparison timeline

Goal: answer what changed between two reports inside the browser.

Planned work:

1. Load comparison output into the SPA.
2. Show added, removed and changed objects.
3. Show relationship changes.
4. Show policy state changes.
5. Add tests for comparison rendering.

### Phase 9: Exports

Goal: make findings easier to share without exposing the full report.

Planned work:

1. Add a sanitised sample report export.
2. Add optional export watermarking.

### Phase 10: Scale and reliability

Goal: keep the report usable on larger tenants.

Planned work:

1. Add request duration metrics.
2. Add collector duration metrics.
3. Add Graph request caching.
4. Add batched or parallel collection where safe.
5. Promote the temporary large synthetic report into a reusable test fixture.
6. Add repeatable browser performance assertions for large graph data.

### Phase 11: Deeper device and sign-in context

Goal: explain access using device and sign-in posture where Graph permissions allow.

Planned work:

1. Collect sign-in risk summaries.
2. Add device compliance policy references if available.
3. Add app consent grant visibility.
4. Add richer device-owner and stale-device insight checks.
5. Add authentication method strength classification from richer Graph method data.

## Community release preparation

Completed on 29 July 2026:

1. Updated author, publisher and copyright metadata for Control Alt Delete Tech Bits.
2. Added the MIT Licence and third-party notices.
3. Added Git exclusions for tenant output, release archives, credentials and local development files.
4. Added contribution, conduct, support and changelog documentation.
5. Added GitHub issue forms, pull request template, code ownership and a read-only validation workflow.
6. Added a source safety scanner for credentials, tenant identifiers, local paths and unintended attribution.
7. Added a clean release builder with an explicit runtime allowlist.
8. Added SHA256 generation and archive entry validation.
9. Added the first-release checklist and private-repository inspection procedure.
10. Produced and clean-tested `IdentityAtlas-v0.14.0-preview.1.zip`.

Latest release validation:

```text
PowerShell tests: 41 passed, 0 failed
JavaScript tests: 8 passed, 0 failed
PSScriptAnalyzer findings: 0
Source safety findings: 0
Unsafe scanner fixture: rejected
Git exclusion paths: 6 of 6 ignored
Clean archive import: passed
Clean archive safety scan: passed
```

The generated ZIP and checksum are stored under the ignored local `Release` directory. No public repository or external release was created during this phase.

Release candidate SHA256:

```text
EA46206F9687D6FB668ECD5AEDEE955D93E38A809F1523DC7737037DCB097A0B
```

## Next recommended task

Create the GitHub personal account and Control Alt Delete Tech Bits organisation, initialise the local repository with Mark Oldham’s verified commit identity, publish it privately and complete `Docs/PRIVATE-REPOSITORY-INSPECTION.md`.
