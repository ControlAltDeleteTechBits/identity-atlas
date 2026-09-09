# Live collection and cancellation validation

Date: 9 September 2026

Status: local 1.1.0 development candidate, not published.

## Fresh authenticated collection

Device authentication used the expected dev tenant, a delegated process context and the isolated local ZIP. No collectors were skipped and no checkpoints were reused for these three runs.

| Run | Objects | Relationships | Evidence records | Coverage |
| --- | ---: | ---: | ---: | --- |
| Core | 512 | 405 | 406 | Partial |
| Governance | 517 | 436 | 433 | Partial |
| Core with optional consent | 524 | 430 | 418 | Partial |

All three runs recorded eight successful per-user authentication method collections and one access-denied response. That denial is retained as unknown coverage, not an empty method list. It is the sole incomplete collector in these fresh reports. The root cause of the Graph denial remains unconfirmed; no role, protection or consent changes were made to bypass it.

Governance collected one Administrative Unit, one unit member and two scoped role assignments. PIM checked 19 groups using 38 requests and returned 24 active assignments, no eligible assignments and no failed group requests. Entitlement Management returned two catalogues, one package and one policy, with no assignments or resource-role scopes. Access Reviews returned no definitions. Successful empty collection does not validate populated eligible assignment, entitlement assignment or review-decision scenarios.

Optional consent collection returned 12 grants. The connection check with Governance and IncludeConsent reported complete scope requirements and explicitly left endpoint access unverified. The session retained an earlier User.ReadWrite.All consent; Identity Atlas warned about it and did not request or use it. A dedicated application containing only the documented read scopes remains a separate validation case.

## Interactive cancellation and recovery

The first Ctrl+C test interrupted application collection. Completed checkpoints were retained and no report was written, but the cancellation summary did not appear. PowerShell had already stopped the pipeline, preventing the output cmdlets in the catch block from running.

The fix adds direct host output in the finally block only when progress remains active after pipeline interruption. It stops the elapsed timer, prints the current collector, completed-stage count, requests and processed totals, explains the absence of a returned completed report, gives checkpoint recovery guidance and clears progress and checkpoint state. Normal completion still uses the information stream.

A second Core attempt finished before Ctrl+C arrived. It is recorded as a completed collection, not a cancellation success.

The corrected Governance test was interrupted during directory-role collection after seven seconds. The summary was visible: three completed stages out of 13, 53 requests, 70 processed objects, 57 relationships and 57 evidence records. No report was written by that interrupted run.

Resume reused the users and groups checkpoints. It refreshed the partial authentication collector and all subsequent stages, retaining original timestamps on reused evidence. The final report contained 517 objects, 436 relationships and 433 evidence records, using 128 new requests with no retries. Coverage remained partial for the known denial and mixed collection timestamps. PIM progress persisted in the transcript at 3/19, 6/19, 9/19, 12/19, 15/19, 18/19 and 19/19 groups.

The first uncorrected run also resumed successfully, producing a Governance and consent report with 529 objects, 461 relationships and 445 evidence records. Its missing interruption summary is not counted as a passing cancellation test.

## Integrity and browser checks

The three fresh reports and both resumed reports had unique node keys, no broken relationship endpoints and no missing evidence references. The resumed reports identify users and groups as the reused collectors.

Chrome checks against the fresh consent report confirmed successful collection wording on a collected user and explicit access-denied wording on the affected user. Insights reported zero successful empty-method responses and one unknown user excluded from negative authentication findings. There was one recognised-strong-method finding among successfully collected privileged users; the unknown user was not treated as having no methods. Console error and warning inspection returned no entries.

Screenshot capture timed out, so a screenshot-based visual pass is not claimed. The report server was restarted after the interrupted desktop session and the existing Chrome tab reloaded successfully. The fresh consent report is available locally on port 8784 while that server is running. Reopening an existing report does not require Graph authentication.

## Automated checks and publication boundary

The final source build passed 88 PowerShell tests and 22 JavaScript tests, with no PSScriptAnalyzer errors or warnings. The added regression stops a real PowerShell runspace pipeline and checks that no report was written and progress and checkpoint state were cleared. The earlier simulated cancellation and resume regression remains in place.

Raw reports, checkpoints and the interactive transcript remain under ignored Output. Only aggregate results are recorded here. Do not publish those private folders. Final package hashes belong in the generated checksum files rather than this document. No GitHub commit, push, draft, release or Gallery publication was performed during these checks.

Remaining validation limits are populated Governance scenarios, dedicated least-privilege application authentication, genuine configuration changes between snapshots, and the screenshot-based visual pass. These limits should remain visible in release documentation.
