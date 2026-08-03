# Identity Atlas v0.15.0 preview 1

Release status: community preview

Identity Atlas v0.15.0 extends the local relationship model into Microsoft Entra external access and Identity Governance. Core collection remains the default. The new Governance profile is opt-in and requests five additional delegated, read-only Microsoft Graph permissions.

## New collection features

1. Nested group membership is represented as a first-class relationship and can be followed through evidence-backed access paths.
2. Cross-tenant access includes the tenant default, partner configurations and cross-tenant synchronisation state.
3. Application management policies include the tenant default, targeted policies and the applications or service principals governed by them.
4. Administrative Units include members, scoped directory role assignments and direct administrator relationships.
5. PIM for Groups includes active and eligible membership or ownership schedule instances.
6. Entitlement Management includes catalogues, access packages, assignment policies, assignments and governed resource roles.
7. Access Reviews include definitions, reviewer scopes, instances, decisions and reviewed resources.

## Report changes

1. Added External access and Governance views.
2. Added filters, labels, icons and evidence panels for each new object and relationship type.
3. Extended access explanations for nested groups, PIM group assignments, access packages, Administrative Units and Access Reviews.
4. Increased evidence-backed path traversal to eight relationships with loop protection.
5. Added collection-profile and governance-capability information to the report manifest.

## Collection profiles

The default Core profile keeps the existing permission set:

```powershell
Connect-IdentityAtlas -UseDeviceCode -CollectionProfile Core -ContextScope CurrentUser
Invoke-IdentityAtlas -CollectionProfile Core -OutputPath .\Output\Tenant
```

The Governance profile adds these delegated read permissions:

```text
AdministrativeUnit.Read.All
PrivilegedAssignmentSchedule.Read.AzureADGroup
PrivilegedEligibilitySchedule.Read.AzureADGroup
EntitlementManagement.Read.All
AccessReview.Read.All
```

Use the profile explicitly for both connection and collection:

```powershell
Connect-IdentityAtlas -UseDeviceCode -CollectionProfile Governance -ContextScope CurrentUser
Invoke-IdentityAtlas -CollectionProfile Governance -OutputPath .\Output\Tenant
```

Identity Atlas does not request any Microsoft Graph write permission. The signed-in account must still hold a Microsoft Entra role accepted by each endpoint. Some Identity Governance data also requires the relevant tenant licence and configured resources. An unavailable endpoint is recorded as partial coverage rather than silently represented as complete.

## Validation evidence

The focused implementation suite covers every new collector and permission boundary:

```text
PowerShell tests: 56 passed, 0 failed
JavaScript tests: 14 passed, 0 failed
PSScriptAnalyzer errors and warnings: 0
Source safety gate: passed
Public release security gate: passed
Browser navigation and filtering against a real-tenant Core report: passed
Browser console errors and warnings: 0
```

Release candidate SHA256:

```text
C19C0845D4E0895D1BE7DAC568B01310EDB3E52E6BEF4B00E0DDA889ACAABF1A
```

Live collection against a tenant containing representative Administrative Units, PIM groups, access packages and Access Reviews remains a post-release validation priority. A tenant without those configured resources can prove endpoint access and empty-result handling, but it cannot prove rendering of data that does not exist.

## Known limits

1. PIM for Groups requires two filtered Microsoft Graph requests for each collected group. Large-tenant throughput needs further live measurement.
2. Identity Governance endpoints may return no objects when the tenant has no matching configuration.
3. A granted delegated scope does not replace the Microsoft Entra role required by an endpoint.
4. The report contains administrative evidence and must be stored and shared as sensitive tenant data.
5. This is preview software. Wider tenant configurations may expose cases that were not present during development testing.
