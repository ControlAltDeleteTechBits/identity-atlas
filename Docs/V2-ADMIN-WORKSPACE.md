# V2 admin workspace development record

Date: 10 September 2026. Local implementation only. The package version remains unchanged; nothing in this phase has been committed, published or released as V2.

## Implemented views

1. Tenant home replaces the initial object selection. It lists collected credential and SAML signing key dates that have passed or fall within 30 days, direct and PIM assignment end dates, unfinished Access Review instance deadlines, missing collected technical owners and incomplete collectors. Items include collection source, evidence references where present, adjacent relationship counts, object inspection and fixed-origin Entra links. A filter limits the displayed attention list to the first 100 matching items. Overall counts include the complete calculated list. These are recorded dates, not predictions of outages or proof that an assignment is still active.
2. Object directory provides users, guests, groups, registrations, service principals and directory roles in a paged table. Search, type and preset filters combine. Column choices, sorting, tenant-scoped saved views, filtered CSV export, page selection and combined relationship inspection are available. The CSV includes every filtered row and the selected columns, not just the visible page. Formula-like values are escaped. Changing filters clears selection; changing pages preserves it.
3. Application administration joins the locally collected registration and service principal. It displays technical owners, assignments, credential metadata, SSO metadata, federation metadata and the existing requested/granted permission dossier. Provisioning and sign-in activity sections display explicit unknowns when absent. These two datasets do not have new collectors in this phase. Local business notes are separate from collected technical ownership.
4. Group housekeeping lists description, observed owners, direct membership and collected dependencies. Directory presets find absent descriptions and no observed dependencies other than owners. Similarity compares direct member sets using Jaccard overlap of at least 50%, preserving each group's different uses. It is not a recommendation to merge or delete. Similarity examines at most 1,000 other groups and 100,000 member comparisons, displays the first 20 matches, and reports truncation.
5. Administration responsibility lists recorded owners separately from role assignment candidates. Candidates require a matching explicit resource action in the collected role definition. Read, create and restore actions alone are excluded because they do not establish administration of this existing object. Active assignment records and eligibility are distinct. Directory and app scope, Administrative Unit membership/restriction metadata, role conditions, schedule evidence and evidence identifiers remain visible. This is not a complete effective-authorisation engine.

## Directory presets

1. Enabled users with no manager returned by a successful explicit manager collection or an explicit null expansion.
2. No observed technical owner.
3. Groups with no observed direct members.
4. Groups missing a description.
5. Groups with no observed dependencies other than owners.
6. Credentials expired or due within 30 days.
7. Guests with direct active or eligible directory role assignments. This deliberately does not label every directory role privileged.
8. Users directly assigned to a selected directory role.
9. Groups used in collected Conditional Access exclusions.

Absence is not automatically confirmed when collection is incomplete. In particular, old reports without manager collection metadata do not satisfy the missing-manager preset. External service principals and managed identities are excluded from the home page's owner reminders, but remain available in the explicit directory filter.

## Collection changes and privacy

User collection expands manager ID/display name. Graph omitted empty manager fields in the first live run, so omitted fields now receive explicit batched manager GETs. HTTP 404 is retained as a recorded no-result response; a denied or failed response remains unknown. The original user may have changed since collection, so this is not a live HR accuracy claim. Requests are bounded to batches of 10.

Service principal collection selects SSO mode, preferred signing thumbprint and key credentials. Only an allowlist of certificate metadata is retained; certificate key material and secret values are discarded. SAML expiry candidates require SAML mode and key usage Sign. Multiple signing keys are not assumed to be the active preferred key. App registration federated credentials are collected through the existing GET batch helper using Application.Read.All, retaining only ID, name, issuer, subject, audiences and description. Failures mark coverage partial. Directory role definitions now retain rolePermissions through the existing RoleManagement.Read.Directory permission.

No permissions were added and no tenant settings were changed. Reports remain offline-capable, with connect-src none and text-node rendering. Portal links are built from a fixed Microsoft Entra origin, URL-encoded object identifiers and tenant context; they are navigation only and remain subject to Microsoft portal route changes. No arbitrary tenant-provided URL is opened.

Saved views and business notes are stored unencrypted in localStorage, scoped to tenant and browser origin. The UI explains this before saving. Notes have explicit save/delete controls, a 4,000-character limit, and are not sent to Entra or embedded in exported reports. Saved views have a clear control and a 30-view limit. Different loopback ports are different browser origins. Storage failures are handled. Treat the browser profile and CSV exports as sensitive tenant material.

Bulk relationship inspection considers at most 50 selected objects and 2,000 adjacent edges. It displays the first 200 edge records and offers a combined graph of the first 100 edges. Limits are visible. It does not infer access through unsupported nested group routes.

## Tests and live validation

The full build passed 97 PowerShell tests and 58 JavaScript tests, including existing access analysis regression tests. New cases cover deadlines, malformed dates, collection warnings, SAML signing usage, missing manager evidence, directory filtering, direct membership overlap, work limits, scoped role candidates, create/read action exclusion, CSV injection protection, fixed-origin links, metadata allowlists, denied federation requests and event-driven directory/navigation/note/export behaviour. Static PowerShell analysis and source safety gates passed. A final syntax/diff check is required after subsequent edits.

Two genuine Core collections were completed without user intervention using the existing authenticated dev tenant context. The second completed in approximately 20 seconds with 512 unique objects, 405 relationships and 562 evidence records. User manager checks completed for nine users; federation collection completed for six registrations; 143 role definitions contained permission actions. The existing authentication-method denial remained partial and was not concealed. Live report analysis exercised all 11 directory presets, 19 group inspections and 308 responsibility inspections without changing the input report.

Chrome exercised the new home page, group filtering, bulk selection, relationship inspection and the combined application administration page using genuine tenant reports. Browser warning/error queries returned no entries during these checks. This is not exhaustive browser or accessibility certification. Fresh data is served privately on port 8788. Previous report data is preserved.

The dev tenant had no SAML-mode application for a positive live certificate expiry case, and no populated review outcome scenario. Those behaviours have automated fixtures but are not claimed as positive live acceptance. Live Access Review testing remains deferred at the user's request. No fixture is shipped as selectable report data.

## Release acceptance, 10 September 2026

The requested release target is stable 2.0.0, with no preview publication. The final versioned build passed 97 PowerShell tests and 58 JavaScript tests. Isolated Chrome checks exercised saved view persistence, filtered CSV, bulk graph inspection, application note save/delete and return navigation. Narrow viewport inspection exposed vertical table heading wrapping; a horizontally scrollable minimum-width table corrected it. Directory redraws now preserve keyboard focus and open filter sections, and navigation generations prevent an old asynchronous view callback from replacing a newer administration view.

The public security check now examines every browser JavaScript asset, including the new administration script. Release packaging and Gallery installation checks are required before publication. Publication status must be verified separately; this record is not a claim that either service already hosts 2.0.0.

## Follow-up work and evidence limits

1. Wider administrator feedback and additional browser/accessibility testing beyond the recorded acceptance checks.
2. Positive live SAML expiry and populated federation cases when suitable authorised objects exist; do not create or change tenant objects solely to force a green result.
3. Review the deliberately limited role-authority model. Wildcards, inherited role actions, conditional permissions, group-supplied administrators, protected targets and restricted management boundaries are not fully evaluated. The panel must remain labelled candidate authority unless those semantics are implemented and tested.
4. Optional provisioning/activity collection requires separate permission, licensing, performance and data-retention decisions. Its absence is displayed, not silently inferred.
5. Retest downloaded public packages after publication and retain the documented evidence boundaries in future changes.

## Microsoft contracts checked

1. [Service principal metadata](https://learn.microsoft.com/en-us/graph/api/resources/serviceprincipal?view=graph-rest-1.0)
2. [SAML signing certificate selection](https://learn.microsoft.com/en-us/graph/application-saml-sso-configure-api)
3. [Federated credential read permissions](https://learn.microsoft.com/en-us/graph/api/federatedidentitycredential-list?view=graph-rest-1.0)
4. [Directory role definition actions](https://learn.microsoft.com/en-us/graph/api/resources/unifiedroledefinition?view=graph-rest-1.0)
