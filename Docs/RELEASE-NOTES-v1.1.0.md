# Identity Atlas v1.1.0

Publisher: Control Alt Delete Tech Bits

Status: prepared release notes. Version 1.1.0 has not been published.

Identity Atlas 1.1.0 improves access explanations, collection recovery and the distinction between missing evidence and missing access.

## Access explanations and findings

1. Corrected nested application and directory role inheritance. PIM ownership, membership and eligibility remain separate.
2. Replaced percentage confidence with evidence labels. A collected relationship is not proof of effective access or a successful sign-in.
3. Added visible limits to graph searches so truncated results are not presented as exhaustive.
4. Recorded authentication collection status for each user. Access-denied, failed and unknown responses do not become findings that a user has no authentication methods.
5. Added direct lookup for referenced directory role definitions missing from the initial list. Failed lookups retain partial evidence.
6. Restricted missing-owner findings to tenant-owned applications and hardened generated remediation arguments against executable tenant text.

## Collection and recovery

1. Added persistent progress messages, PIM group counts, failure counts and completion guidance. A blocked HTTP request can still delay a progress update.
2. Added optional checkpoints and resume. Reused evidence retains its original timestamps and reports identify mixed collection coverage.
3. Fixed the interruption summary when Ctrl+C stops PowerShell's output pipeline.
4. Added connection diagnostics and optional delegated consent collection. Satisfied scope requirements do not guarantee endpoint access: roles, licensing and resource restrictions still apply.
5. Added public commands to reopen saved reports and stop report servers owned by the current session.

## Report review

1. Added comparison JSON import to Timeline and masked evidence previews.
2. Added tenant, schema and coverage checks to comparison. Missing records in incomplete snapshots are not confirmed removals.
3. Reports remain local. Report folders and checkpoints contain sensitive tenant information and require access controls. Masked previews do not sanitise the underlying report files.

## Validation and limits

The candidate passed 88 PowerShell tests and 22 JavaScript tests, with no PSScriptAnalyzer errors or warnings. Fresh authenticated Core, Governance and optional consent runs completed against the development tenant. Real Ctrl+C interruption and checkpoint resume were also verified.

One authentication-method request was denied by Microsoft Graph and is correctly shown as unknown coverage. Its cause remains unconfirmed. Populated eligible PIM group assignments, entitlement assignments and Access Reviews were not available in that tenant. Dedicated application authentication using only the documented read scopes, genuine configuration changes between snapshots and screenshot-based visual verification remain outstanding validation cases. Browser interaction checks passed; screenshot capture timed out.

See [the validation record](LIVE-VALIDATION-2026-09-09.md) for evidence and limits.

## Install after publication

These commands are for use once version 1.1.0 is available on PowerShell Gallery. Close PowerShell sessions using the old module before upgrading, then open PowerShell 7.

```powershell
Install-Module IdentityAtlas -RequiredVersion 1.1.0 -Scope CurrentUser -Force
Import-Module IdentityAtlas -RequiredVersion 1.1.0
Connect-IdentityAtlas -UseDeviceCode -ContextScope Process
Invoke-IdentityAtlas -OutputPath "$env:USERPROFILE\Documents\IdentityAtlas-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -OpenReport
```

Read the README and security guidance before collection. Do not attach tenant reports or checkpoints to public issues.
