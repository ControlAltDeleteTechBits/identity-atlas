# Access verification phase

## Current implementation, 10 September 2026

Follow-up fixes and latest validation are recorded in [Extended validation](EXTENDED-VALIDATION-2026-09-10.md). The final follow-up build passed 91 PowerShell and 47 JavaScript tests. Live Access Review tests are deferred at the user's request; automated review regression tests remain enabled. Export rendering, baseline retention, comparison presentation and unsupported permission-type handling have been corrected locally. No publication has occurred.

All six analysis models and their Details panels are implemented locally. This is not a release announcement. No tenant assignments, review decisions or sessions are changed. The historical first-increment log below is retained as a progress record, not the current feature status.

1. Access removal verification: select a user or application, open Details and choose data/report.json from an earlier snapshot. The panel identifies disappearing direct memberships, directory role and application assignment routes, alternatives for the same permission and scope, eligible routes and unverified conclusions. Application registrations use their collected service principal. This complements Compare-IdentityAtlas; the command's output contract is unchanged.
2. Access Review outcome verification: the same baseline selector correlates the principal's review decision, apply result, resource and later assignment evidence. States distinguish pending application, reviewed path removed, alternative remaining and unable to verify. A confirmed result requires a single identifiable direct reviewed path, successful application and chronological complete evidence. Ambiguous app roles and group-supplied application access are not guessed. At most 100 decisions are inspected. A newer collected decision supersedes its earlier state.
3. PIM protection: select a directory role and open Details > Is PIM protecting this role? The panel separates eligibility, standing schedules, activations and unknown active assignment types, including direct group members. Alternatives are matched by principal, role, directory scope and app scope. Policy evidence includes approval, authentication, authentication context and maximum duration; assignment expiry remains separate. Missing group PIM evidence prevents a membership being labelled standing. Group activation policies are not inferred from role policies.
4. Group dependency inspector: select a group and open Details. Direct dependencies are grouped into assignments, Conditional Access inclusions, exclusions, memberships, governance and context. Choose an observed direct membership in Local membership change preview to inspect affected and remaining paths and policy scope consequences. This is not a deletion safety verdict or live Conditional Access evaluation.
5. Dynamic group explanation: for a group with a collected rule, choose an observed member in the preview. The panel shows the rule, attributes, condition results, observed membership and downstream paths. Supported grammar is user attributes with eq/ne, and/or and parentheses. Supported attributes: department, accountEnabled, userType, jobTitle, companyName, country, city, officeLocation and userPrincipalName. Unsupported operators, attributes, escaping and collection expressions remain unevaluated. Calculation does not establish when Entra membership processing completed. Attribute write-authority analysis remains a later extension.
6. Application permission dossier: select an application or registration and open Details > Application permission dossier. Requests and grants are matched by resource API, permission ID and type. The panel separates application and delegated permissions, individual-user and tenant-wide consent, missing grants, unmatched grants, descriptions, owners and credential expiry. Delegated grants require the existing IncludeConsent option. Resource-level authorisation outside collection is explicitly unknown.

### Collection changes

User collection retains a limited set of rule attributes. Missing response properties stay missing rather than becoming explicit null values. Service principals retain app role and delegated scope definitions. Review decision edges retain decision ID and application time.

Directory roles collect assignment schedule instances and expanded role management policy rules using the existing RoleManagement.Read.Directory permission. Schedules join by roleAssignmentOriginId, retaining overlapping instances and original evidence. Missing or paginated expanded rules mark coverage partial. No new write permission is requested. Administrator roles, licensing and endpoint access can still restrict collection.

Collector metrics now retain collectionStartedAtUtc and collectionCompletedAtUtc. Checkpoints preserve the original timestamps.

### Evidence boundaries

Removing configuration is not proof of token revocation or terminated application sessions. The interface states this beside the controls and in results.

Comparison requires the same tenant and schema and strictly increasing valid snapshot timestamps. Confirmed removal also requires matching complete coverage, complete original path evidence and later collector timestamps after the reference snapshot. Old reports without collector timing remain readable but cannot support confirmed-removal conclusions. A review's application time must precede the later collectors, not merely report generation.

The route verifier does not inherit enterprise application or directory-role assignments through nested groups. Ownership is not membership. Eligibility is not active access. Expired, future and invalid dates are not current alternatives. Different permission IDs or scopes are not treated as equivalent grants.

Dependency inspection examines 500 adjacent records and displays 50 per category. Route searches inspect at most 5,000 edges and return 500 paths. PIM inspection is bounded to 500 rows. General result rendering shows at most 100 items per collection. Limits are visible and prevent exhaustive absence claims.

Baseline files are limited to 64 MB and stay local. Tenant strings use text nodes, not HTML or executable rule expressions. Evidence identifiers are expandable. Reports and screenshots still contain tenant data and must remain private.

### Validation and remaining release acceptance

The final suite contains 91 PowerShell tests and 43 JavaScript tests, including decision-state replacement, activation-rule separation and eligible PIM membership remaining after ordinary membership removal. Cases cover all six models, alternatives, eligibility, exact scope/permission matching, incomplete evidence, invalid dates, stale checkpoints, failed review application, ambiguous reviewed permissions, unsupported rules, PIM group activation ambiguity and bounded searches. The build also runs PowerShell analysis, JavaScript syntax validation and source safety checks. Final run results are retained in the ignored local work/access-analysis-build.log.

The source safety scan inspected 125 files with zero findings before this documentation update. A Graph expanded-collection annotation triggered an email-pattern false positive; a narrow quoted-property exception resolved it without disabling email detection.

Chrome loaded a private preview generated from an existing genuine tenant export. User verification controls, role protection, back navigation, group membership preview selection and the application dossier were exercised. Old schedule/policy evidence correctly remained unknown. The browser returned no warning or error console entries during those checks. Screenshot capture timed out and automated file chooser population was denied, so visual and end-to-end upload tests are not claimed as passed. The group preview was refined to show remaining paths only for affected entitlements, with readable target labels rather than internal keys.

Fresh authenticated Core, Governance and Governance with consent collections completed on 10 September 2026. Live testing exposed an HTTP 400 when the directory role assignment query selected appScopeId. Using the default role assignment representation resolved the error without discarding returned scope evidence. A regression assertion now checks that endpoint. The corrected build passed 91 PowerShell and 43 JavaScript tests.

The corrected private reports contain 512 objects, 405 relationships and 562 evidence records for Core; 517, 436 and 589 for Governance; and 529, 461 and 601 with consent. Each contains policy evidence on 145 role objects and schedule evidence on 11 assignment relationships. Directory roles and the governance collectors completed. One authentication-method request returned HTTP 403, correctly leaving overall coverage partial. No tenant configuration was changed.

The tenant contains no Access Review definitions or decisions, so these runs do not validate an applied review outcome. Remaining release acceptance includes manual file-picker and viewport checks, and a real before/after removal and review scenario on explicitly authorised disposable tenant objects. This development task does not authorise making tenant changes automatically. Unit tests do not replace those checks. Overall partial coverage deliberately prevents confirmed-removal claims under the current conservative comparison model.

Nothing has been published. Review the diff, choose a release version and repeat packaging checks before a separate GitHub/Gallery publication step.

### Controlled live membership test, 10 September 2026

With explicit approval, a single existing user was temporarily added to an empty test group through the Entra portal. Graph confirmed the membership before the Core baseline was collected. Only that membership was then removed through the portal; a separate Graph GET confirmed the group was empty again before the second Core collection. The user and group were not deleted. Collection permissions were unchanged.

The unmodified browser analysis function was exercised against the genuine private before and after report files using an ignored local validation script. Assertions passed: exactly one membership disappeared, the removed target was absent from the supported subsequent routes, four other collected paths remained, and the session limitation was retained. Overall coverage remained partial because of the authentication-method denial. The comparison correctly returned `Unable to verify removal: path no longer observed`, rather than a confirmed-removal claim. This validates the incomplete-coverage branch with real evidence, not the complete-coverage success branch or applied Access Review outcomes. The browser file-picker workflow still requires separate validation. Private reports and the helper script are excluded from publication.

### Microsoft references checked

1. [Review decision contract](https://learn.microsoft.com/en-us/graph/api/resources/accessreviewinstancedecisionitem?view=graph-rest-1.0)
2. [Access Reviews FAQ](https://learn.microsoft.com/en-us/entra/id-governance/access-reviews-faqs)
3. [Role policy assignments](https://learn.microsoft.com/en-us/graph/api/policyroot-list-rolemanagementpolicyassignments?view=graph-rest-1.0)
4. [Role assignment schedule instances](https://learn.microsoft.com/en-us/graph/api/rbacapplication-list-roleassignmentscheduleinstances?view=graph-rest-1.0)
5. [Dynamic membership rules](https://learn.microsoft.com/en-us/entra/identity/users/groups-dynamic-membership)
6. [Permissions and consent](https://learn.microsoft.com/en-us/entra/identity-platform/permissions-consent-overview)

## Historical first-increment log

Started: 10 September 2026. Local development only; not published.

IdentityAtlas remains separate from IntuneAccess. No new Graph permissions are requested by this phase's first increment.

## Implementation order

1. Group dependency inspector: implemented locally. Group Details now separates direct role and application assignments, Conditional Access inclusions and exclusions, membership and PIM relationships, governance and review connections, and other context. It displays evidence provenance, unresolved references and inspection limits. This is not a group deletion safety verdict or a transitive access calculation.
2. Access removal verification: pending. Compare selected source, target and exact permission or scope between chronological snapshots. Show removed paths and remaining alternatives. Refuse cross-tenant or reversed-time comparisons; incomplete coverage and search truncation prevent absence claims. Session revocation remains outside the model.
3. Access Review outcome verification: pending. Correlate decision, apply result, exact reviewed resource and subsequent relationship evidence. Missing targets or ambiguous resource matches stay unknown. An applied decision does not establish removal of every alternative path.
4. PIM alternative-route analysis: pending. Match role and assignment scope, distinguish active, eligible, expired and future assignments, and avoid treating a PIM activation as independent standing access. Collect activation policies only after endpoint and read-permission review; missing policy evidence remains unknown.

## First increment boundaries

The inspector uses existing incoming and outgoing indexes and examines at most 500 adjacent records. Each category displays at most 50 inspected records with a visible limit message. Unknown relationship types remain contextual rather than disappearing. Nested membership is inspectable but does not imply inherited application or directory-role access. PIM ownership is not membership and eligibility requires activation.

The inspector never changes tenant configuration. Tenant labels and evidence are rendered through text nodes. The evidence drawer is unmasked local evidence, not a share-safe export.

## Acceptance tests

Automated regression cases cover category separation, incoming ownership, complete and missing evidence, unresolved objects, empty results, unknown relationship types, bounded high-degree groups, no inferred nested-role inheritance and text-only rendering of hostile labels. Run build.ps1 for the complete PowerShell and JavaScript suite. Browser and fresh tenant checks must be recorded separately; neither is implied by unit tests.

The remaining three features need positive, negative, incomplete, conflicting-time, hostile-input and bounded-search cases before being marked implemented. No new release version or publication is authorised by this development record.

## Validation result, 10 September 2026

The first increment passed build.ps1: 88 PowerShell tests and 27 JavaScript tests, including five new dependency inspector cases. PSScriptAnalyzer reported no errors or warnings, and git diff --check passed. Browser interaction, visual inspection and fresh live collection have not yet been performed for this increment. Existing exported reports do not automatically acquire the new interface; regenerate or deliberately update a private preview before browser testing.
