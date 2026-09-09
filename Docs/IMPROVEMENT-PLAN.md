# Identity Atlas improvement plan

Updated: 8 September 2026

Publisher: Control Alt Delete Tech Bits

Status: local 1.1.0 development candidate. Not committed, pushed or published. The public stable release remains 1.0.0.

This is the current roadmap. PROJECT-LOG.md and older design documents retain historical decisions and test results; their old estimates and feature gaps are not current commitments.

## Implemented changes

1. Application and directory role paths reject nested group inheritance. Nested relationships remain available for inspection and supported policy scope routes.
2. PIM group ownership is a terminal contextual relationship rather than membership. Eligible membership routes explicitly require activation. Evidence completeness is not presented as a probability of effective access.
3. Path search has budgets of eight relationships, 50 returned routes, 20,000 inspected edges or queued states, and 1.5 seconds of worker search time. Results say when a budget truncated the investigation.
4. Comparison rejects different tenants and incompatible schemas. If either snapshot is partial or collector coverage differs, absent records are classified as not observed, not confirmed removals. This deliberately conservative decision applies across the comparison.
5. Timeline accepts locally selected comparison.json, verifies tenant, schema and later snapshot timestamp, and displays changes and property values. It shows up to 100 records per category with an explicit limit message. Exact change time is not inferred from observation dates.
6. Evidence and finding exports open a preview. Masking is enabled by default. Masked output contains only object aliases and allowlisted relationship labels. Names, identifiers, tenant labels, free text, endpoint paths, state and remediation commands are omitted. Structure can still disclose information; review before sharing. This is not screenshot masking.
7. Open-IdentityAtlasReport reopens an existing tenant report without Graph sign-in. Stop-IdentityAtlasReport stops only a server registered in the current module session, checking its process start time to protect against reused identifiers.
8. Test-IdentityAtlasConnection describes the current Graph context and scope assessment without collecting tenant data. It does not claim to verify licensing, administrator roles or live endpoint authorisation.
9. Optional checkpoints retain completed collector results and original timestamps. A resumed run refreshes the first incomplete collector and every downstream collector. Reused evidence marks the report partial and names reused collectors.
10. Collection settings can be saved and reused. Only profile, skipped collectors, batch size and the consent option are stored; there are no credentials or account details.
11. Delegated consent grants are collected only with IncludeConsent. They distinguish AllPrincipals and Principal grants, the client service principal, resource API, scope strings and an individual subject where applicable. Requested API permissions remain distinct from grants. Service principal app role assignments remain available separately.
12. The history gate preserves community authorship without restricting every author to the maintainer. StrictMaintainerHistory remains available for historical inspections. Protected review, signed main commits and repository permissions remain the trust boundary, not editable Git names.
13. Publish-IdentityAtlasGitHubRelease.ps1 builds and scans a clean tagged checkout, creates a draft, uploads assets, downloads and verifies the archive, then publishes only with an explicit Publish switch and confirmation. It does not replace published assets or silently overwrite existing draft assets.
14. Missing-owner findings now cover app registrations and service principals whose recorded publisher is this tenant. External publishers, unknown publishers and managed identities are excluded from this specific check, not declared safe. Owner commands use the correct application or service principal resource. Executable identifier arguments accept only UUIDs, otherwise showing placeholders; display names are restricted to a single comment line. Requested Graph permissions are labelled as requests rather than grants.

## Local usage

Import this checkout explicitly until the candidate is published:

```powershell
Import-Module .\IdentityAtlas.psd1 -Force
Test-IdentityAtlasConnection
Connect-IdentityAtlas -UseDeviceCode -ContextScope Process
$result = Invoke-IdentityAtlas -OutputPath .\Output\Review -OpenReport -Checkpoint -SaveSettingsPath .\review-settings.json
Stop-IdentityAtlasReport -ProcessId $result.ServerProcessId
$server = Open-IdentityAtlasReport -Path .\Output\Review
Stop-IdentityAtlasReport -ProcessId $server.ProcessId
```

Resume an interrupted or partial collection in the same output location:

```powershell
Invoke-IdentityAtlas -OutputPath .\Output\Review -Resume -SettingsPath .\review-settings.json -OpenReport
```

Checkpoint identity binds tenant, account, client, granted scopes, profile, skipped collectors, batch settings, implementation version and collector source hashes. Changes require a fresh collection. Checkpoints expire after 24 hours. A checkpoint folder has no report marker and is not a report the viewer can serve. Checkpoints contain sensitive tenant evidence and are not encrypted. Store them with the same controls as reports. They are not automatically deleted. Interrupted work within one collector restarts that collector; there is no request-level resume or delta synchronisation.

Stop only accepts processes launched in the current imported module session. After restarting PowerShell, open the report again to obtain a newly managed server. It does not stop arbitrary processes based only on a port number.

For optional delegated consent:

```powershell
Connect-IdentityAtlas -UseDeviceCode -IncludeConsent -ContextScope Process
Invoke-IdentityAtlas -OutputPath .\Output\ConsentReview -IncludeConsent -OpenReport
```

IncludeConsent adds Directory.Read.All only when the default requested scopes are used. If Scopes is explicitly supplied, that list remains authoritative. An accepted administrator role is also needed. The default Core and Governance scope sets are unchanged. No Graph write permission is requested.

Compare reports, then select comparison.json in the later report's Timeline:

```powershell
Compare-IdentityAtlas -ReferenceReportPath .\Output\Earlier -DifferenceReportPath .\Output\Later -OutputPath .\Output\Comparison
```

## Validation record

9 September follow-up: referenced-role fallback implemented and verified against recorded live responses without authenticating or changing the tenant. See LIVE-VALIDATION-2026-09-08.md. Build static analysis now examines root PowerShell files and Private, Public, Tests and tools, excluding generated reports, extracted packages and private diagnostic scripts under Output.

Follow-up validation passed 76 PowerShell tests and 20 JavaScript tests, with no source static-analysis warnings or errors. The source safety scan checked 117 files with zero findings. The candidate ZIP and Gallery package were subsequently rebuilt and validated on 9 September. A fresh authenticated Core run from the ZIP passed the role-recovery check with complete directory-role coverage. The separate authentication-method 403 remains. Package hashes and results are recorded in LIVE-VALIDATION-2026-09-08.md. No commit, push or publication was performed.

Fresh authenticated Core, Governance and optional consent runs have now completed. See [LIVE-VALIDATION-2026-09-08.md](LIVE-VALIDATION-2026-09-08.md) for results, partial coverage and scenarios with no live records. The remaining-check statements below describe what the earlier implementation build had not tested.

The final implementation build passed 72 PowerShell tests and 20 JavaScript tests, with no PSScriptAnalyzer errors or warnings. Checks covered checkpoint round trips, expiry and empty results, retry invalidation, partial comparison, incompatible tenant and schema rejection, consent projections, unsafe process stopping, direct and nested paths, PIM classification, assignment dates at report time and a dense cyclic graph budget. Additional UI helper tests verify owner finding scope, correct remediation resource types, hostile tenant text handling and masked evidence allowlisting. The dense graph test also verified the truncation diagnostic.

The public release gate passed 13 checks across current source, all 46 Git commits and the local release archive. The Gallery package passed 16 checks, including its isolated import. These are local candidate packages, not published downloads.

Browser checks used an existing LiveTenant export rendered with the candidate assets. Application search and inspection, the no-route caveat, contextual versus assignment labels, evidence completeness without percentages, default masked preview, full preview, Escape dismissal and Timeline comparison import passed. The comparison used the same snapshot on both sides as a zero-change smoke check and showed the partial-coverage warning. No browser errors or warnings were recorded during these interactions. This does not replace testing changed records from two fresh collections.

Open-IdentityAtlasReport served the saved export without Graph authentication. With the requested port occupied it selected the next port, returned HTTP 200 and was stopped through Stop-IdentityAtlasReport in the same session. The existing server was left running.

The release helper was statically analysed but has not created a remote draft. It rejects existing draft assets, checks the draft asset list, and verifies both the downloaded ZIP and checksum file before allowing publication. Remote publication, fresh Gallery installation and authenticated collection are pending release checks.

Live validation is separate from mocked tests. Existing tenant reports can validate rendering, but do not prove fresh Graph collection or the presence of representative Governance and consent resources.

The final browser pass also checked the revised owner-finding filter and masked finding export. The saved tenant snapshot produced six tenant-owned application findings, compared with 269 entries under the earlier unrestricted rule. This is a change of check scope, not evidence that tenant risks have been remediated. No Graph writes were performed.

## Release test matrix

1. Source and complete-history tenant-data and secret scans.
2. PSScriptAnalyzer with no errors or warnings.
3. Every PowerShell and JavaScript test passing, including negative access-rule cases.
4. Clean archive import exposing the seven intended commands.
5. Gallery package metadata, dependency, checksum and isolated import checks.
6. Browser search, path labels, application inspection, Timeline import and evidence preview.
7. No new browser console errors; keyboard access to new controls and dialog close.
8. Fresh live Core collection using the candidate from an isolated package.
9. Fresh configured Governance and optional consent collection with source records checked against Graph results.
10. Consent failure and partial coverage must remain visible.
11. Interrupted collection, resume and incompatible-context rejection.
12. Reopen, port fallback and safe server stopping.
13. Generated report and checkpoint exclusion from the release archive.
14. GitHub draft assets verified before publication; published package downloaded and retested afterwards.

Items requiring authenticated tenant resources or publication are not implied by a passing mocked build. Do not claim those checks passed until their evidence is recorded.

## Collection usability follow-up, 9 September 2026

Four improvements are implemented locally, without committing or publishing:

1. Authentication coverage is recorded by user key in the devices and authentication collector metrics. Successful empty responses, successful method collection, denied requests, other failures, malformed responses, skipped collection and missing responses have distinct states. The map survives collector checkpoints. Negative authentication findings require successful per-user collection; existing reports without this metadata remain unknown. Registration evidence does not prove enforcement. Windows Hello and Temporary Access Pass detection now recognises Graph's camel-case type names.
2. Progress retains information-stream messages when work advances and five seconds have elapsed, plus the final item update. PIM groups report checked and total groups and failed request counts. Request updates retain the PIM failure count. There is no periodic timer during a blocked HTTP request, and reported object progress is not a deduplicated report total.
3. Completion prints the saved path, deduplicated totals, complete and incomplete collectors, skipped data, next actions and a safely quoted reopening command. These messages remain visible when the result is assigned to a variable. Browser startup failure does not discard a saved report. Cancellation explains whether a checkpoint is available and that processed counts are not a completed report.
4. Optional consent requirements are included in Connect, Test Connection and collection preflight when IncludeConsent is selected. Explicit scope lists are not silently broadened. A complete local scope assessment leaves endpoint access unverified; it does not prove roles, licensing or resource authorisation.

Regression coverage includes denied, failed, empty, successful, malformed, missing and skipped authentication responses; checkpoint round trips; consent opt-in for Core and Governance; PIM progress and cancellation propagation; completion command quoting; a full mocked interrupted collection and resume; legacy report exclusions; and Graph method-name matching.

The final source build passed 87 PowerShell tests and 22 JavaScript tests, with no PSScriptAnalyzer errors or warnings. The timestamp round-trip assertion compares UTC instants, avoiding a false failure caused by PowerShell JSON conversion and the local time zone.

Local publication gates passed 13 checks, including 119 current source text files with zero scan findings and all 46 existing commits, plus archive exclusion and checksum checks. Gallery validation passed 16 checks, including an isolated package import. No remote publication occurred. Audited ZIP SHA256: EC71961C88315EF3AFBECA113F3B03CB3F27397F7247088D33C2A57F388C1DDA. Audited Gallery package SHA256: 35BCDD28EDBC5163C3EC3085DD2CFA77F76CED36E298C2562513026CA99F9D25. This verification record was updated after those archives were built; regenerate final publication packages after the remaining live validation and documentation are complete.

The mocked cancellation test interrupted the groups collector after users were checkpointed. No report was written by the cancelled run. Resume reused users once, restarted groups and produced a partial report with the original evidence timestamps. This is not a live Ctrl+C test or proof that a blocked Graph request cancels immediately.

Chrome DOM checks against an existing live tenant export confirmed the per-user unknown status, retained relationships and exclusions from both negative authentication findings. Console error and warning inspection was empty. Screenshot capture timed out twice, so a visual screenshot pass is not claimed. No tenant records were replaced with fixtures or invented statuses.

Update: fresh Core, Governance and consent collection and real interactive cancellation and resume are now verified in [LIVE-VALIDATION-2026-09-09.md](LIVE-VALIDATION-2026-09-09.md). The live Ctrl+C test exposed a missing summary that simulated cancellation did not reproduce. Direct host output in the finally block fixes that stopped-pipeline case and clears progress state. The repeated live test and resume passed. The final suite now contains 88 passing PowerShell tests and 22 passing JavaScript tests, including a real runspace pipeline stop regression. Earlier counts and hashes above describe the preceding candidate, not the rebuilt cancellation fix.

## Follow-on work

1. Add measured 10,000-user and larger edge fixtures with documented memory, loading and interaction budgets. The historical million-edge design target is not a supported-scale claim.
2. Expand coverage-aware comparison from conservative report-level decisions to collector-specific decisions when object provenance is sufficient.
3. Introduce property-level change highlighting and affected route comparison beyond opening the changed object in the current graph.
4. Consider request-level checkpoint recovery and delta collection after the collector-level implementation has received live testing.
5. Review pending dependency pull requests through protected checks. Do not merge major updates only because they are available.
6. Perform a separate accessibility review at supported viewport sizes and browser zoom levels.

## References

Microsoft application assignment restrictions: https://learn.microsoft.com/en-us/entra/identity/enterprise-apps/assign-user-or-group-access-portal

PIM membership and ownership activation: https://learn.microsoft.com/en-us/entra/id-governance/privileged-identity-management/groups-activate-roles

Delegated permission grants and permissions: https://learn.microsoft.com/en-us/graph/api/oauth2permissiongrant-list?view=graph-rest-1.0

Delegated grant fields: https://learn.microsoft.com/en-us/graph/api/resources/oauth2permissiongrant?view=graph-rest-1.0

Service principal owner commands: https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.applications/new-mgserviceprincipalownerbyref?view=graph-powershell-1.0
