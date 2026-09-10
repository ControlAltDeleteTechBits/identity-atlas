# Identity Atlas 2.0.0

Stable release. Publisher: Control Alt Delete Tech Bits. Maintainer: Mark Oldham.

## What is new

1. Tenant administration home: upcoming collected credential, SAML signing key, role assignment and review dates, plus owner and collection attention items.
2. Object directory: searchable, sortable tables, custom columns, saved local views, filtered CSV export and combined relationship inspection.
3. Application administration: registration and enterprise application linkage, technical ownership, local business notes, assignments, credentials, SSO metadata, federation metadata and permission explanations.
4. Group housekeeping: missing description and ownership candidates, observed membership, dependency context and bounded direct-membership similarity.
5. Candidate administration responsibility: collected role actions, active versus eligible assignments, scope and Administrative Unit evidence, separate from technical ownership and business notes.
6. Access verification: earlier-snapshot import, disappearing paths, remaining alternatives, PIM protection context, supported dynamic membership rule explanation and Access Review outcome analysis.
7. Export and usability fixes: correct SVG/PNG connectors and icons, retained in-memory comparison baselines, clear incomplete-evidence explanations, readable narrow-screen tables and retained keyboard focus after row selection/sorting.

## Install or update

Run in a fresh PowerShell 7 window:

```powershell
Install-Module IdentityAtlas -RequiredVersion 2.0.0 -Scope CurrentUser -Force
Import-Module IdentityAtlas -RequiredVersion 2.0.0
Connect-IdentityAtlas -UseDeviceCode -ContextScope Process
Invoke-IdentityAtlas -OutputPath "$env:USERPROFILE\Documents\IdentityAtlasReport" -OpenReport
```

Complete the Microsoft device sign-in, then keep the same PowerShell window open for collection. The final output includes a local report URL. Reopening an existing report does not require another Graph collection:

```powershell
Open-IdentityAtlasReport -Path "$env:USERPROFILE\Documents\IdentityAtlasReport"
```

Choose a new output directory if an existing report must be preserved. Existing report folders do not acquire new features automatically: collect a new report using V2. Checkpoints from earlier versions must not be resumed with V2. The existing public commands and schema 1.1.0 are retained; generated reportVersion is now 2.0.0. The initial page is now tenant administration rather than the object graph.

## Security and evidence boundaries

Collection remains delegated and read only. This release adds no requested Graph permissions. Additional GETs collect manager and federation metadata; existing batch limits, retry behaviour and progress apply. Certificate metadata excludes key material and secret values. No Identity Atlas service receives tenant reports.

Saved filters and notes are stored unencrypted in the local browser origin, scoped to the tenant, and have explicit clearing controls. They are not Entra configuration and are not included in exported report files. Different ports are different browser origins. Protect the browser profile, reports, screenshots and CSV files as sensitive tenant information. Never put secrets into business notes.

The role responsibility panel is a candidate list, not a complete effective-authorisation verdict. Wildcards, inherited actions, action conditions, group supplied administrators, protected target rules and restricted Administrative Unit boundaries are not fully evaluated. Eligibility is not active access. Missing records are not proof of absence when collection is incomplete.

The application page displays provisioning and activity as not collected when unavailable; this release does not add those collectors. SAML signing keys are expiry candidates and are not all assumed to be the currently preferred signing key. The directory guest-role preset includes direct directory role assignments and does not label every role privileged.

Removing assignments does not establish token revocation or termination of existing application sessions. Verification searches have explicit limits and incomplete collection prevents confirmed removal conclusions under the conservative comparison model.

## Validation scope

Automated tests cover collection metadata, failed and denied requests, access path boundaries, expiry dates, role scope candidates, group similarity limits, CSV injection protection, offline rendering and UI event handling. A fresh dev tenant Core collection validated manager metadata, federation endpoint access and role actions without tenant writes. The pre-existing authentication-method denial remains visible as partial coverage.

Real-browser checks covered saved views, filtered exports, application notes, bulk relationships, object navigation and narrow-screen layout. These are acceptance checks, not a guarantee of every tenant configuration or browser combination.

Live Access Review outcome acceptance remains deferred. Positive SAML expiry and populated federation scenarios were covered by controlled automated data, not by creating objects in the dev tenant. Those limits are not concealed by the stable version label. See [the V2 implementation record](https://github.com/ControlAltDeleteTechBits/identity-atlas/blob/v2.0.0/Docs/V2-ADMIN-WORKSPACE.md) and [access verification boundaries](https://github.com/ControlAltDeleteTechBits/identity-atlas/blob/v2.0.0/Docs/ACCESS-VERIFICATION-PLAN.md).
