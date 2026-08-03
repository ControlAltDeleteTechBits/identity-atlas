# Identity Atlas release security review

Date: 3 August 2026

Reviewed version: 0.15.0 preview candidate

Review status: passed for local preview use

## 1. Security boundary

Identity Atlas is a read only PowerShell collector and local static report. PowerShell authenticates to Microsoft Graph with delegated permissions, requests selected directory data and serialises a normalised relationship model. The browser reads the generated files and does not call Microsoft Graph.

The report is administrative evidence. It can contain user principal names, object identifiers, group descriptions, application metadata, role assignments, Conditional Access assignments, device posture and authentication method types.

## 2. Threats considered

1. Requesting Microsoft Graph write permissions.
2. Serialising access tokens, passwords, client secret values or certificate material.
3. Allowing one failed collector to misrepresent a partial report as complete.
4. Recording unsafe exception text in the report.
5. Following a malicious Microsoft Graph pagination link to another host.
6. Serving sample data as though it came from a tenant.
7. Serving files outside the selected report folder.
8. Serving an arbitrary folder that is not a complete Identity Atlas report.
9. Browser code making unexpected network requests.
10. Browser framing, MIME confusion, caching or referrer leakage.
11. Writing a generated report over Identity Atlas source files or a filesystem root.
12. Interrupted report writes leaving partially written JSON or JavaScript files.

## 3. Microsoft Graph permission assessment

Identity Atlas requests delegated read permissions only. It does not request application permissions or any permission containing ReadWrite.

The default requested scopes are:

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

The optional Governance profile adds exactly these delegated read permissions:

```text
AdministrativeUnit.Read.All
PrivilegedAssignmentSchedule.Read.AzureADGroup
PrivilegedEligibilitySchedule.Read.AzureADGroup
EntitlementManagement.Read.All
AccessReview.Read.All
```

Core remains the default profile. Governance permissions are requested only when the administrator selects `-CollectionProfile Governance`. The security gate loads the module and checks both recommended scope sets so a future change cannot hide a write permission behind dynamic scope selection.

The scope assessment now checks the scopes returned by `Get-MgContext`. Missing recommended scopes are shown after connection and are recorded as partial coverage in the report. Documented higher privilege alternatives are recognised if an administrator already has them, but Identity Atlas does not request those alternatives by default.

Microsoft Graph delegated permissions are limited by both the granted scope and the signed in administrator's Microsoft Entra role. A correct scope can still return HTTP 403 if the account does not hold a role supported by the endpoint.

Identity Governance availability can also depend on the tenant licence and configured resources. Identity Atlas records those failures as partial collection coverage and does not claim an empty or forbidden endpoint is complete.

## 4. Endpoint groups and least privilege

### Users

Endpoints include `/v1.0/users`.

Requested scope: `User.Read.All`.

### Groups

Endpoints include `/v1.0/groups`, group members and group owners.

Requested scope: `Group.Read.All`.

`GroupMember.Read.All` is sufficient for basic membership, but it does not cover the full group and owner information collected by Identity Atlas.

### Applications

Endpoints include applications, service principals, owners and app role assignments granted to service principals.

Requested scope: `Application.Read.All`.

### Devices

Endpoints include devices and registered owners.

Requested scope: `Device.Read.All`.

### Authentication methods

Endpoint: `/v1.0/users/{id}/authentication/methods`.

Requested scope: `UserAuthenticationMethod.Read.All`.

The signed in administrator also needs a supported Microsoft Entra role. Microsoft documents Global Reader, Authentication Administrator and Privileged Authentication Administrator for acting on other users. Identity Atlas stores method identifiers and method types, not phone numbers, email addresses, secret values or authentication material.

### Conditional Access

Endpoints include Conditional Access policies and named locations.

Requested scope: `Policy.Read.All`.

The signed in administrator also needs a supported Microsoft Entra role for these endpoints.

### Authentication strengths

Endpoint: `/v1.0/policies/authenticationStrengthPolicies`.

The least privileged standalone permission is `Policy.Read.AuthenticationMethod`. Identity Atlas already requires `Policy.Read.All` for Conditional Access policies and named locations, so it does not request an additional scope.

### Directory roles

Endpoints include role definitions and active role assignments.

Requested scope: `RoleManagement.Read.Directory`.

### Eligible directory roles

Endpoint: `/v1.0/roleManagement/directory/roleEligibilityScheduleInstances`.

Requested scope: `RoleEligibilitySchedule.Read.Directory`.

### Administrative Units

Endpoints include `/v1.0/directory/administrativeUnits` and the members of each collected unit.

Requested Governance scope: `AdministrativeUnit.Read.All`.

### PIM for Groups

Endpoints include active assignment schedule instances and eligible schedule instances. Microsoft Graph requires each request to be filtered by group or principal identifier, so Identity Atlas issues two read requests per collected group.

Requested Governance scopes: `PrivilegedAssignmentSchedule.Read.AzureADGroup` and `PrivilegedEligibilitySchedule.Read.AzureADGroup`.

### Entitlement Management

Endpoints include catalogues, access packages, assignment policies, assignments and expanded resource role scopes.

Requested Governance scope: `EntitlementManagement.Read.All`.

The signed-in account must also hold an accepted Entitlement Management role, such as Access package manager or Catalog owner, or a supported Microsoft Entra role such as Identity Governance Administrator.

### Access Reviews

Endpoints include definitions, instances and decisions.

Requested Governance scope: `AccessReview.Read.All`.

The signed-in account must hold a supported Microsoft Entra role for the type of review being read. Access reviews of Microsoft Entra role assignments have a narrower supported-role set than group or application reviews.

## 5. Token and credential handling

1. `Connect-IdentityAtlas` returns tenant, account, authentication type and scope names. It does not return an access token.
2. Access tokens remain inside the Microsoft Graph PowerShell authentication context.
3. Report metadata declares `tokenDataSerialized` as false.
4. Error sanitisation removes bearer values and common authentication query parameters before a warning is added to a report.
5. Application credential nodes contain credential type, key identifier, display name and validity dates only.
6. Passwords, client secret values, `secretText`, certificate bytes and raw Graph responses are not serialised.
7. Automated tests scan the generated report for bearer tokens and sensitive property names.

The default authentication context is `Process`. This is preferred for one off collection because the context ends with the PowerShell process. `CurrentUser` context should be selected only when persistent sign in is intentional.

Run this after collection when the Graph session is no longer needed:

```powershell
Disconnect-MgGraph
```

## 6. Partial collection handling

Every top level collector now runs through a protected boundary. If a collector fails, Identity Atlas creates an empty partial result, records a sanitised warning and continues with the remaining collectors.

Individual subresource failures, such as one user's authentication methods or one group's owners, also remain partial rather than ending the report.

Coverage is complete only when the permission assessment and every collector complete successfully. Missing objects and unresolved relationship endpoints remain visible as warnings.

## 7. Microsoft Graph request controls

1. Collection uses GET requests only.
2. Relative request paths must begin with `/v1.0/` or `/beta/`.
3. Absolute pagination links must use HTTPS.
4. Pagination hosts are limited to documented Microsoft Graph hosts for the global, United States Government and China operated clouds.
5. Links containing user information or fragments are rejected.
6. HTTP 429, 502, 503 and 504 responses use bounded retry handling.
7. Retry counts and request duration are recorded as collector metrics.

## 8. Report package controls

1. Report files are written through a temporary file and moved into place after the write succeeds.
2. The writer refuses filesystem roots, the project root and Identity Atlas source folders.
3. Every generated report includes `.identity-atlas-report.json`.
4. The package marker records the report version, schema version, origin and generation time.
5. The local server requires the index, manifest and package marker.
6. Package and manifest data origins must match.
7. Sample fixture reports are always rejected by the local server.

## 9. Local server controls

1. The listener binds to `127.0.0.1` only.
2. Only GET and HEAD are accepted.
3. Canonical path validation prevents access outside the exact report root, including similarly named sibling folders.
4. Request lines, header count and total header size are bounded.
5. Read and write timeouts are applied to each client.
6. Browser caching is disabled.
7. Responses set content type protection, framing protection, referrer protection, permissions restrictions and a restrictive Content Security Policy.
8. The server does not set cross origin access headers.

## 10. Browser controls

The Content Security Policy uses `default-src 'none'`, permits local scripts and styles, permits the locally generated graph worker, and sets `connect-src 'none'`.

The interface inserts tenant strings through `textContent` and DOM attributes. It does not build tenant content with `innerHTML`, `document.write`, `eval` or `new Function`.

The support email and donation link are explicit administrator actions. Selecting either link leaves the local report.

Review states, layout preferences and pinned object identifiers are stored in browser local storage using a tenant specific key. Administrators should clear site data on shared devices.

## 11. Administrator handling guidance

1. Store reports only on an access controlled device.
2. Do not place live reports in a public web root, shared drive or source repository.
3. Treat exported PNG, SVG, Markdown, CSV and JSON files with the same care as the full report.
4. Delete reports and exports according to the organisation's evidence retention policy.
5. Use the loopback development server only.
6. Stop the local server after review.
7. Disconnect Microsoft Graph when collection is complete.
8. Do not send a report to support unless it has been reviewed and sanitised.

## 12. Residual risks and release decisions

1. A person who can read the report files can read the collected directory evidence. Identity Atlas does not encrypt reports.
2. Browser local storage can retain tenant identifiers, review states and pins until site data is cleared.
3. Delegated consent is currently granted to the Microsoft Graph Command Line Tools client used by Microsoft Graph PowerShell. A dedicated Identity Atlas application registration remains a decision for a later release.
4. The local server does not attempt to resolve or reject every possible filesystem reparse point. The report root must remain administrator controlled.
5. Report exports can be shared outside Identity Atlas controls.
6. One live authentication method request previously returned HTTP 403 because delegated scope and administrator role requirements are both enforced by Microsoft Graph.

## 13. Validation evidence

The 0.15.0 Identity Governance development candidate passed:

```text
PowerShell tests: 56 passed, 0 failed
JavaScript graph worker tests: 14 passed, 0 failed
PSScriptAnalyzer findings: 0
Source safety findings: 0
Public release security checks: 11 passed, 0 failed, with history intentionally excluded from the uncommitted local candidate
Release archive forbidden paths: 0
Release archive import: passed
Release archive SHA256: B0E53A8B4ED010D4C001FF9EA55742E75AB3D7A08D8E91C8F11B9DEFB2A89C99
```

All new collectors have focused mocked Graph-response tests. The worker suite also checks nested group paths, PIM group paths, access-package grants, Administrative Units, Access Review decisions and application management policies. Live Governance collection is a separate gate because it requires interactive delegated consent and representative tenant configuration.

The previous public 0.14.0 review evidence remains below for traceability.

The 0.14.0 Identity Atlas community-release build passed:

```text
PowerShell tests: 45 passed, 0 failed
JavaScript graph worker tests: 8 passed, 0 failed
PSScriptAnalyzer findings: 0
Live report HTTP status: 200
HEAD request status: 200
POST request status: 405
Sibling folder traversal attempt: 403
Test-fixture report without explicit allowance: blocked
Incomplete report root: blocked
Browser console errors: 0
```

The existing live development tenant report retained the expected object, relationship and evidence counts when upgraded to the Identity Atlas 0.14.0 package format. The tenant was not recollected during this review because no reusable Microsoft Graph PowerShell context was available.

Community-release controls also passed:

```text
Source safety findings: 0
Public release security checks: 13 passed, 0 failed
Git history snapshots scanned: 11
Unexpected author or committer identities: 0
Unsafe Graph write methods: 0
Unsafe browser network or code-evaluation patterns: 0
Clean release archive import: passed
Clean release archive safety scan: passed
SHA256 verification: passed
```

The verified release candidate SHA256 is:

```text
E062075D5169AEF9E7566DADFE82A1C94058D79BA33C398B8C06CC8AB180CE20
```

## 14. Official Microsoft references

1. Microsoft Graph permissions overview: https://learn.microsoft.com/graph/permissions-overview
2. Microsoft Graph permissions reference: https://learn.microsoft.com/graph/permissions-reference
3. List users: https://learn.microsoft.com/graph/api/user-list?view=graph-rest-1.0
4. List group members: https://learn.microsoft.com/graph/api/group-list-members?view=graph-rest-1.0
5. List application owners: https://learn.microsoft.com/graph/api/application-list-owners?view=graph-rest-1.0
6. List service principal owners: https://learn.microsoft.com/graph/api/serviceprincipal-list-owners?view=graph-rest-1.0
7. List app role assignments granted for a service principal: https://learn.microsoft.com/graph/api/serviceprincipal-list-approleassignedto?view=graph-rest-1.0
8. List devices: https://learn.microsoft.com/graph/api/device-list?view=graph-rest-1.0
9. List registered device owners: https://learn.microsoft.com/graph/api/device-list-registeredowners?view=graph-rest-1.0
10. List authentication methods: https://learn.microsoft.com/graph/api/authentication-list-methods?view=graph-rest-1.0
11. List Conditional Access named locations: https://learn.microsoft.com/graph/api/conditionalaccessroot-list-namedlocations?view=graph-rest-1.0
12. List authentication strength policies: https://learn.microsoft.com/graph/api/authenticationstrengthroot-list-policies?view=graph-rest-1.0
13. List eligible role instances: https://learn.microsoft.com/graph/api/rbacapplication-list-roleeligibilityscheduleinstances?view=graph-rest-1.0
14. List Administrative Unit members: https://learn.microsoft.com/graph/api/administrativeunit-list-members?view=graph-rest-1.0
15. List PIM for Groups active assignment schedule instances: https://learn.microsoft.com/graph/api/privilegedaccessgroup-list-assignmentscheduleinstances?view=graph-rest-1.0
16. List PIM for Groups eligibility schedule instances: https://learn.microsoft.com/graph/api/privilegedaccessgroup-list-eligibilityscheduleinstances?view=graph-rest-1.0
17. List access-package resource role scopes: https://learn.microsoft.com/graph/api/accesspackage-list-resourcerolescopes?view=graph-rest-1.0
18. List Access Review definitions: https://learn.microsoft.com/graph/api/accessreviewset-list-definitions?view=graph-rest-1.0
19. List Access Review decisions: https://learn.microsoft.com/graph/api/accessreviewinstance-list-decisions?view=graph-rest-1.0
