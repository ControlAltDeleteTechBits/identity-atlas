# Extended validation, 10 September 2026

Scope: local development build, genuine private tenant exports and the local browser report. No tenant writes, permission changes or publication were performed in this validation pass. The original findings are retained below; see the subsequent fix record for current status.

## Results

1. Full build passed: 91 PowerShell tests and 43 JavaScript tests. Build includes source safety checks, PowerShell static analysis and JavaScript syntax validation. No static-analysis warning or error stopped the build. Log retained privately in work/extended-validation-build.log.
2. Across Core, Governance and consent exports, 2,769 analysis calls completed without exceptions. Per export: 302 route queries, 146 role protection inspections, 280 application dossiers, 171 rule evaluations, 15 membership previews and nine review queries. Input reports remained unchanged. Rule cases in this tenant primarily exercise missing-rule behaviour; empty review results do not validate applied decisions. Aggregate analysis time was 84 to 91 milliseconds per export on this device, not a large-tenant performance claim.
3. Additional assertions rejected same-time comparisons, different tenants, incompatible schemas and invalid membership selections. Altered metadata existed only in memory for negative tests; genuine reports were not modified.
4. The controlled removal comparison was rerun against genuine before and after reports. Exactly one membership disappeared, four other supported paths remained, and partial coverage prevented a confirmed-removal claim. The session caveat remained present.
5. User-assisted browser file selection was verified in the rendered UI. The conclusion and remaining paths were visible. Evidence/Details tab switching retained the result. Selecting another user and returning did not retain it.
6. Main navigation controls were exercised, including Overview, Groups, Applications, Roles, Policies, External access, Governance, Insights, Timeline and Settings. Settled Settings content was inspected. The Core report displayed guidance that Governance data was not collected. Rapid navigation snapshots can precede rendering; this is a smoke check, not exhaustive acceptance of every section.
7. Zoom in, zoom out and fit controls were exercised. Browser warning/error log queries returned no entries during the checks. This is not evidence that all possible browser errors are absent.
8. PNG export produced a file in the local Downloads directory. Direct visual inspection found the defects below. The export contains private tenant information and must not be published.

## Findings

### High priority: exported graph rendering

The PNG displays curved edges as black filled shapes and omits node icons. Web/assets/app.js currentGraphSvgContent clones the graph but defines graph-edge stroke without fill:none. It also removes all image elements. The same serialisation feeds SVG export, so SVG requires regression validation too. Fix export styling and safely preserve local icon assets; add rendered export tests rather than testing file creation alone.

### Medium priority: comparison state is lost on object changes

After a user selects a baseline, changing the selected object and returning clears the results and file selection. Switching Evidence/Details alone retained it. Keep the parsed baseline in memory for the current report session, clearly show its filename and timestamp, provide a clear action, and recompute the result per selected principal. Do not silently persist private baseline data to browser storage.

### Medium priority: unsupported requested permission types

Two requested permission records in the genuine export have permissionType Role,Scope. A fresh read-only Graph query returned the same value, so this is not established as a collector flattening bug. The dossier only explicitly distinguishes Role from Scope and should identify unsupported values as unevaluated, rather than implying a normal match or mismatch. Preserve the raw evidence and add a regression case.

### Medium priority: comparison explanation and readability

Verified: No is shown before a clear reason, in a narrow nested details panel. Display the disappeared-path result and the specific coverage limitation first, then alternative routes and expandable technical evidence. The screenshot confirms this is hard to interpret despite correct conservative model output.

## Subsequent fix record

The four findings have local fixes. Export connectors explicitly use fill:none. Export icons use path geometry from the bundled Tabler assets, embedded as SVG elements with fixed styling. No network requests, external image references or arbitrary SVG markup are imported. A first implementation using local fetch was rejected by the existing offline security gate and replaced, without weakening that gate. Corrected PNG output was visually inspected: black fills are gone and user, role, policy, application, group, device and authentication icons are present. SVG also exported without browser warnings or errors.

The comparison baseline is now retained only in page memory across object selections. Its filename and timestamp are shown; Clear baseline discards it. Invalid replacements preserve the prior baseline, and a sequence counter prevents stale asynchronous reads from replacing newer selections. Reloading or closing the page intentionally discards the baseline. The result now leads with disappeared path count and a named incomplete-collector warning, separates conclusions into cards and collapses other paths and technical details. Unsupported requested permission types are explicitly unevaluated, with their raw value retained.

Regression coverage includes unsupported permission types, offline export structure, baseline state controls and baseline load/re-render/invalid replacement/clear behaviour. The updated assets are deployed only to the private report on port 8787; no release was published. Live Access Review acceptance testing is deferred at the user's request, not marked passed. Existing automated review tests remain enabled.

Final build passed 91 PowerShell tests and 47 JavaScript tests, including the new baseline behaviour regression. Source safety, offline browser security checks and git diff --check passed. The 2,769 genuine-report analysis calls and controlled removal assertions were rerun successfully. Baseline retention was validated with an event-driven DOM test; the revised browser file-picker flow was not repeated because automation cannot populate that chooser. No additional user intervention was requested.

## Remaining limits

Complete-coverage removal success and applied Access Review outcomes have automated coverage, but not live positive acceptance in this tenant. Authentication-method access remains partially denied; no permission expansion or omission of evidence was used to make coverage appear complete. There are no existing review decisions for a live outcome test. No additional tenant objects or reviews were created. Responsive viewport coverage and exhaustive export formats remain incomplete. No release-readiness claim is made.
