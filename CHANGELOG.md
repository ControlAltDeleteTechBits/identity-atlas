# Identity Atlas changelog

This file records user-facing changes. Identity Atlas uses semantic versioning for stable releases and an additional preview label before version 1.0.

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
