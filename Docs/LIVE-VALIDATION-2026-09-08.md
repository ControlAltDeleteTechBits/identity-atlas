# Fresh dev tenant validation

Date: 8 September 2026

Status: completed with coverage limits. No publication or tenant configuration changes.

## Packaged role-fix retest, 9 September

A fresh authenticated Core collection from the rebuilt, checksum-verified ZIP passed the role-fix check. It resolved the previously omitted AdHoc License Administrator definition and recovered its active assignment. The directory-role collector returned complete coverage: 146 definitions, 12 active assignments, one eligible assignment, one direct lookup, no unresolved definitions and no retries. The full collection took 24.44 seconds and 122 requests, producing 511 unique objects, 404 relationships and 405 evidence records. Graph endpoints and evidence references passed integrity checks.

Only the previously reproduced authentication-method HTTP 403 remains in report coverage warnings. No permissions or tenant configuration were changed. This retest supersedes the earlier statement below that fresh role-fix validation was outstanding; it does not close the other populated-resource and least-privilege test gaps.

Tested ZIP SHA256: C5A731F7096FD58107218A02ECEE7BD2224A6749A8B735D84D0E09106E002393.

Rebuilt Gallery package SHA256: FD1AD3CB7A724EC5AF94011C2933983FC48EA23FB415E8C846AB7970388FF021. All 16 Gallery checks passed. The rebuilt ZIP passed 11 source and package checks; unchanged Git history was not rescanned in that invocation. Neither package was published. This validation note was added after packaging and does not alter the tested package bytes.

## Method

The local 1.1.0 candidate ZIP was checksum-verified, extracted into an isolated directory under ignored Output, and imported by its explicit manifest path. Microsoft device authentication used a process-scoped delegated context restricted to the dev tenant recorded in the previous live export. No checkpoints, skipped collectors or sample reports were used.

The same authenticated context had the Governance and optional consent scopes for all runs. This verifies collection behaviour, but does not establish that every endpoint works with only the minimum Core scopes. The context included a previously granted User.ReadWrite.All scope. The connection command warned about this; Identity Atlas did not request or use that permission. A dedicated read-only application context remains a separate least-privilege validation task.

## Collection results

| Run | Duration | Requests | Retries | Unique objects | Relationships | Evidence |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: |
| Core | 17.83 seconds | 121 | 0 | 510 | 403 | 404 |
| Governance | 81.11 seconds | 167 | 0 | 515 | 434 | 431 |
| Core with consent | 16.11 seconds | 122 | 0 | 522 | 428 | 416 |

All three reports correctly recorded partial coverage. Graph returned HTTP 403 for one user's authentication methods. A directory role assignment referenced a role definition that was not returned. Their underlying causes have not been independently established. Neither gap should be represented as no authentication methods or no role access.

Progress object totals count collector contributions before deduplication; the table uses final unique report objects. PIM collection took roughly one minute for 38 requests across 19 groups, with no reported failures or retries.

## Populated live resources

1. Administrative Units: one unit, one member and two scoped role assignments. Collector complete.
2. PIM for Groups: 15 active member and nine active owner relationships. Collector complete.
3. Entitlement Management: two catalogues, one package and one assignment policy. Collector complete.
4. Delegated consent: 11 AllPrincipals grants and one Principal grant. All 12 grant references resolved. Collector complete.

Eligible PIM group assignments, access-package assignments, entitlement resource role scopes and Access Review definitions returned no records. Successful empty responses are not populated-feature validation. No test resources were created or licences changed.

## Report and worker checks

All reports had matching manifest counts, unique node and evidence keys, resolved edge endpoints and valid evidence references. The generated worker was executed against the fresh reports: all nine PIM owner routes remained terminal contextual relationships; all 12 application consent routes carried the delegated-consent interpretation; the individual consent route was also present.

Comparing Core with Governance produced five newly observed objects and 31 newly observed relationships. The coverage warning correctly explains that these need not be newly created tenant records. No removals were claimed. These closely spaced runs test collection-profile differences, not deliberate configuration changes.

Fresh Governance and consent reports were served locally on ports 8780 and 8781. Earlier browser interaction tests are recorded in IMPROVEMENT-PLAN.md; this run additionally verified the actual generated worker against live records, not a new full visual browser audit.

## Remaining release checks

This section preserves the original diagnostic state. Later role recovery, per-user authentication coverage and live interruption/resume results are recorded in [LIVE-VALIDATION-2026-09-09.md](LIVE-VALIDATION-2026-09-09.md). Statements below about unimplemented fixes or pending collection describe the earlier stage, not the latest candidate.

### Follow-up diagnostic findings

Update, 9 September: the role-definition fallback is now implemented locally. Active and eligible assignments share a single lookup per missing identifier. Failed, empty or mismatched lookups retain an unresolved role node and assignment evidence marked partial. An offline replay of the recorded diagnostic responses recovered 146 definitions and all 12 active assignments with one direct lookup. This replay made no Graph requests; a fresh authenticated run of the changed collector is still outstanding. Authentication-method handling and tenant permissions were not changed.

Targeted delegated GET requests completed on 8 September after fresh process-scoped authentication. No tenant writes or additional permissions were requested. Raw diagnostic responses remain under ignored Output.

The missing role was returned by a direct roleDefinitions/{id} request as AdHoc License Administrator, built-in and enabled. It was absent from the independently retrieved list of 145 definitions, while one of 12 returned assignments referenced it. The current collector only resolves definitions from the list and skips assignments whose definitions are missing. Recommended correction: fetch each distinct missing referenced definition once, validate the returned identifier, and retain unresolved assignment evidence if lookup fails. This correction has not yet been implemented.

The affected user's standard properties were readable, but a direct authentication/methods GET independently returned HTTP 403. The signed-in account had a returned tenant-scoped Global Administrator assignment, and the connection scope assessment was complete. The Governance export also shows the affected user in a restricted management Administrative Unit. This is relevant context, not a proven cause: Microsoft's restricted-management documentation describes modification restrictions and permits standard-property reads; it does not establish the reason for this specific authentication-method read denial. No role assignment, protection removal or permission expansion was attempted.

Keep this user's method coverage unknown. Do not report that they have no methods merely because Graph denied collection. Further confirmation needs an appropriately authorised scoped administrator or Microsoft support, without automatically broadening access. The overall 403 root cause remains unconfirmed.

References: [authentication methods permissions](https://learn.microsoft.com/en-us/graph/api/authentication-list-methods?view=graph-rest-1.0), [restricted management Administrative Units](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/admin-units-restricted-management).

1. Independently investigate the authentication-method 403 and missing role definition using authorised read-only diagnostics. Do not broaden consent automatically.
2. Validate populated eligible PIM assignments, package assignments and Access Reviews in an appropriately configured test tenant.
3. Validate a dedicated application with only the documented delegated read scopes.
4. Test interrupted collection and resume against live data, and verify changed records across two genuine configuration snapshots.
5. Complete publication-specific draft checks and download/install testing only when release is authorised.

Tenant identifiers, account names, endpoints containing object identifiers, raw evidence and reports remain in ignored local Output. This document contains aggregate results only.
