# Identity Atlas changelog

## 2.0.0

1. Added the tenant administration home, paged object directory, saved views, custom columns, sorting, CSV exports and combined object relationship inspection.
2. Added application administration, group housekeeping and candidate administration responsibility views with explicit scope and coverage limits.
3. Collected manager metadata, SSO signing certificate metadata, federation metadata and directory role actions using existing read permissions.
4. Added access removal and review outcome verification, PIM protection analysis, group dependency previews, supported dynamic rule explanation and application permission dossiers.
5. Retained comparison baselines across object selections, corrected PNG/SVG connectors and icons, and labelled unsupported requested permission types unevaluated.
6. Preserved local-only processing, added a security gate covering all browser scripts, and improved narrow-screen table scrolling and keyboard focus after selection/sorting.
7. Changed the initial screen to administration home. Existing commands and schema 1.1.0 remain compatible; regenerate reports to obtain the new UI and metadata. Old checkpoints must not be reused across this version change.

See Docs/RELEASE-NOTES-v2.0.0.md for validation boundaries, including deferred live Access Review acceptance and candidate rather than definitive administrative authority.

## 1.1.0

1. Corrected nested application and directory role inheritance, separated PIM ownership and eligibility, and replaced percentage confidence with evidence labels.
2. Bounded graph search by depth, examined edges, queue size, result count and time. Truncation is visible.
3. Added tenant, schema and coverage checks to comparison. Missing records in incomplete snapshots are not confirmed removals.
4. Added comparison JSON import to the Timeline view and masked evidence previews.
5. Added public report opening, safe session-owned server stopping and connection diagnostics.
6. Added optional collection settings and checkpoints, retaining evidence timestamps and refreshing failed collectors and their downstream stages.
7. Added explicit delegated consent collection with opt-in Directory.Read.All consent.
8. Updated contributor attribution checks and added a verified draft-first GitHub publication helper.
9. Restricted missing-owner findings to tenant-owned applications, corrected service principal owner commands and guarded remediation arguments against executable tenant text. Requested Graph permissions are explicitly labelled as requests, not grants.
10. Resolve missing referenced directory role definitions with one direct lookup per identifier across active and eligible assignments. Preserve assignments and partial evidence when lookup fails, returns no result or returns a different identifier.
11. Record authentication collection status per user. Denied, failed, skipped, incomplete and older unknown responses are excluded from negative authentication findings. Successful empty responses remain distinct from missing evidence.
12. Retain periodic terminal progress messages, with PIM group totals and failure counts. Collection summaries include complete and incomplete collectors, next actions and a report reopening command.
13. Check optional delegated consent scopes in connection diagnostics and collection preflight. Scope checks explicitly leave endpoint authorisation unverified.
14. Preserve cancellation through PIM and device request handlers, explain checkpoint recovery, and recognise Graph's camel-case Windows Hello and Temporary Access Pass method names.
15. Print an interruption summary and clear progress state even when Ctrl+C has already stopped PowerShell's output pipeline. Verified with a real pipeline-stop regression and live cancellation and resume.

This file records user-facing changes. Identity Atlas uses semantic versioning for stable releases and an additional preview label before version 1.0.

## 1.0.0

Released as the first stable Identity Atlas version.

### Security

1. Removed raw tenant JSON from the inline script in `Compare-IdentityAtlas` HTML output.
2. Comparison data now loads from a separate local JavaScript resource under a restrictive Content Security Policy.
3. Added hostile tenant-string regression coverage for closing script tags and prohibited browser execution primitives.
4. Added optional dedicated Microsoft Entra application and tenant identifiers to `Connect-IdentityAtlas`.
5. Added an in-report control that clears Identity Atlas pins, review states and layout settings from browser storage.

### Release controls

1. Promoted the module and report format to stable version 1.0.0.
2. Pinned development analysis dependencies and enabled automated GitHub Actions dependency updates.
3. Updated security, installation and dedicated application guidance for the stable release.
4. Retained immutable GitHub assets, SHA256 checksums, tenant-data scanning and isolated Gallery package validation.

### Compatibility

Existing 0.16.0 reports remain readable. The four public commands retain their existing names and default behaviour. `ClientId` and `TenantId` are optional additions to `Connect-IdentityAtlas`.

## 0.16.0-preview.1

Release date: 5 August 2026

### Added

1. Live collector progress with the active stage, current item count and total collector count.
2. Elapsed time plus cumulative Microsoft Graph request, retry, object, relationship and evidence totals.
3. Clear warnings when Microsoft Graph throttles or temporarily rejects a request, including the retry delay and attempt number.
4. A cancellation summary covering elapsed time, completed collectors and collected totals.
5. `-SkipSlowCollectors` and granular `-SkipCollector` options for deliberately reduced collections.
6. `-BatchSize` control from 1 to 20 for authentication method, application role assignment and application owner requests.
7. Automatic loopback report serving and browser opening when `-OpenReport` is used.
8. Automatic selection of the next available permitted loopback port when the requested port is occupied.

### Changed

1. Per-user authentication method requests now use bounded Microsoft Graph JSON batches.
2. Per-application role assignment and owner requests now use bounded Microsoft Graph JSON batches.
3. The invocation result now includes duration, request and retry totals, skipped collector names, report URL and local server process ID.
4. Deliberately skipped collection is recorded as partial coverage with an explicit warning and collector metric.

### Security

1. Resource operations remain GET only. POST is restricted to the Microsoft Graph `/v1.0/$batch` transport, and every batch subrequest is validated as GET against an allowed Microsoft Graph v1.0 path.
2. The automatic web server remains bound to `127.0.0.1`, validates the report package and refuses automated fixture data.

## 0.15.1-preview.1

Release date: 4 August 2026

### Added

1. PowerShell Gallery metadata for the project, licence, 85 by 85 product icon, release notes and PowerShell Core compatibility.
2. A declared Microsoft.Graph.Authentication dependency at the minimum version used for live validation.
3. A dedicated Gallery package builder that consumes the matching checksummed GitHub release archive.
4. A repeatable Gallery package gate covering metadata, dependency declarations, archive boundaries, checksums, tenant-data scanning and clean import.
5. Continuous integration coverage for building and testing the Gallery package without publishing it.

### Changed

1. Updated the module and report version to 0.15.1 preview 1.
2. Added PowerShell Gallery preview installation guidance while retaining the verified GitHub ZIP installation path.

### Security

1. Gallery packages are generated only from the matching checksummed GitHub release archive.
2. Generated NuGet packages reject reports, tests, workspace output, Git metadata, certificates and release folders.
3. Publisher credentials are not accepted by the package builder and are not stored in the repository.

## 0.15.0-preview.1

Release date: 3 August 2026

### Added

1. An explicit opt-in Governance collection profile with five delegated read permissions.
2. Nested group path traversal with intermediate-group evidence and loop protection.
3. Default and partner-specific cross-tenant access settings.
4. Tenant-default and targeted application management policies, including policy-to-application coverage.
5. Administrative Units, member relationships and role assignments scoped to Administrative Units.
6. Active and eligible PIM for Groups membership and ownership schedules.
7. Entitlement Management catalogues, access packages, assignment policies, assignments and resource roles.
8. Access Review definitions, reviewer scopes, instances, decisions and reviewed resources.
9. Governance and External access browser views, object filters, labels and graph relationship groups.
10. Focused PowerShell and JavaScript tests for every new collector and access-path type.

## 0.14.0-preview.1

Release date: 29 July 2026

First community preview prepared by Control Alt Delete Tech Bits.

### Added

1. Read-only Microsoft Graph collection for users, groups, applications, directory roles, devices, authentication methods and Conditional Access resources.
2. Offline single-page report with client-side search, filtering, navigation and relationship expansion.
3. Evidence-backed access explanations for users and applications.
4. Graph export to Mermaid, SVG and PNG.
5. Finding evidence export and remediation PowerShell snippets.
6. Finding review states and action plans.
7. Change timeline, coverage diagnostics and access-path confidence.
8. Permission blast-radius and Conditional Access impact views.
9. Stale-device and weak-authentication-method checks.
10. Relationship grouping, breadcrumbs and tenant-specific pinned objects.
11. JSON, CSV and Markdown exports.
12. Comparison reports for added, removed and changed objects and relationships.
13. Loopback-only development server with report-package validation.
14. Community contribution, support, security and release documentation.

### Security

1. Delegated Microsoft Graph permissions are read only.
2. Authentication material is removed from collector errors.
3. Generated reports use a restrictive Content Security Policy.
4. The local server rejects fixture reports and incomplete report packages.
5. Live tenant output is excluded from source control and release archives.

### Fixed

1. Complete Microsoft Graph permission coverage now returns an empty missing-scope summary without a PowerShell strict-mode error.
2. Downstream relationship collectors now accept empty upstream node collections after Microsoft Graph denies or omits a resource.
3. The Conditional Access empty state now explains that both Policy.Read.All and a supported Microsoft Entra role are required.

### Known limitations

1. Coverage may be partial when Microsoft Graph permissions or administrator roles do not allow a collector to read a resource.
2. Nested group traversal is not used for directory-role access paths.
3. Conditional Access simulation is evidence based and does not replace Microsoft policy evaluation.
4. Reports contain administrative evidence and must be stored securely.
