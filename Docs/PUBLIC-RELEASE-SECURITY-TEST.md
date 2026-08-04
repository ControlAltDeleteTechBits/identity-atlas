# Identity Atlas public release security test

Date: 4 August 2026

Current release: `v0.15.1-preview.1`

Current release result: passed

Published GitHub release SHA256:

```text
3086FB203C0C3E174EE0D7FBC185DDBDC58BFFE6C61180E4A091280663AF4875
```

Published PowerShell Gallery package SHA256:

```text
D53795D21C6B90A9BD45EBED480676A0D7B056BD962BAA6684AAFC6193E850DF
```

## Purpose

This test checks the source, complete Git history and release package before public visibility. It is intended to detect tenant evidence, credentials, unsafe write permissions, unexpected browser networking, risky workflow permissions and unintended authorship.

Run it from the repository root:

```powershell
.\tools\Test-IdentityAtlasPublicRelease.ps1 `
    -ReleasePath .\Release\IdentityAtlas-v0.15.1-preview.1.zip
```

GitHub Actions runs the same gate against the release package built by the workflow. CI skips the full history loop because the complete history is checked locally before publication.

## Results

1. Current source safety scan: passed.
2. Tracked path boundary: passed.
3. Default delegated Microsoft Graph scopes are read only: passed.
4. PowerShell dynamic evaluation and remoting check: passed.
5. Microsoft Graph request method check: passed with GET only.
6. Offline browser execution boundary: passed.
7. Content Security Policy check: passed.
8. GitHub Actions trust boundary: passed.
9. Git history authorship check: passed.
10. Complete Git history content scan: 28 snapshots passed.
11. Release package checksum: passed.
12. Release archive content allowlist: passed.
13. Extracted package safety and module-manifest validation: passed.

The separate PowerShell Gallery gate passed 16 checks covering source metadata, dependency metadata, checksums, package boundaries, local PSResourceGet discovery, tenant-data scanning and clean import.

The test found no tracked tenant report, user export, object identifier, tenant domain, access token, client secret, certificate, local user path or confidential screenshot.

All reviewed commits use Mark Oldham or the verified `MarkCADTB` GitHub account as author with Mark@controlaltdeletetechbits.co.uk. Direct commits use the same approved human identity as committer. Protected GitHub squash merges use the exact `GitHub <noreply@github.com>` committer identity. No additional contributor attribution is present.

## Permission findings

The default Microsoft Graph permissions are delegated and contain no write permission:

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

The collector’s Microsoft Graph wrapper only issues GET requests. The browser report does not call Microsoft Graph or another network service.

Microsoft documents `RoleEligibilitySchedule.Read.Directory` as the least-privileged delegated permission for listing role eligibility schedule instances. Microsoft documents `Policy.Read.All` for listing Conditional Access policies and also requires the signed-in user to hold a supported Microsoft Entra role.

## Browser and local server findings

1. Browser code does not use `innerHTML`, `document.write`, `eval`, `new Function`, `fetch`, `XMLHttpRequest`, WebSocket or `sendBeacon`.
2. The report policy includes `default-src 'none'` and `connect-src 'none'`.
3. The local server binds to `127.0.0.1`.
4. GET and HEAD are accepted; POST is rejected.
5. Test fixture reports and incomplete packages are rejected.
6. The support and donation links require an explicit administrator action.

## GitHub findings

1. Repository visibility is public and was verified without an authenticated GitHub session.
2. Workflow permissions are limited to `contents: read`.
3. Checkout does not retain Git credentials.
4. GitHub Actions dependencies are pinned to full commit identifiers.
5. `pull_request_target` is not used.
6. Dependency graph, Dependabot alerts, Dependabot security updates and grouped security updates are enabled.
7. Bug, feature and security-report routes recognise the checked-in templates.
8. Private vulnerability reporting is enabled.
9. Secret Protection and push protection are enabled.
10. Dependabot malware alerts are enabled.
11. CodeQL default analysis is enabled and its first run completed successfully.
12. The Community Profile recognises the README, licence, code of conduct, contribution guide, security policy, issue forms and pull request template.
13. Content reporting is enabled for all GitHub users.
14. The active `Main branch protection` ruleset targets the default branch.
15. The ruleset blocks deletion and force pushes.
16. Pull requests, resolved conversations, an up-to-date branch and the `PowerShell and JavaScript tests` check are required.
17. Repository administrators retain an emergency bypass for the one-maintainer project.

## Residual risks

1. Generated reports are not encrypted. Anyone who can read a report folder can read its administrative evidence.
2. A report can retain tenant-specific pins and review states in browser site data.
3. An administrator can export evidence to files outside Identity Atlas controls.
4. Microsoft Graph coverage depends on both consented scopes and the signed-in user’s Microsoft Entra role.
5. The first preview has been tested in a development tenant; wider use may reveal tenant configurations not present in that test.

These risks are disclosed in the README, security review and release notes. They do not justify adding write permissions or sending report data to a hosted service.

## Official Microsoft references

1. Microsoft Graph permissions overview: https://learn.microsoft.com/graph/permissions-overview
2. List Conditional Access policies: https://learn.microsoft.com/graph/api/conditionalaccessroot-list-policies?view=graph-rest-1.0
3. List role eligibility schedule instances: https://learn.microsoft.com/graph/api/rbacapplication-list-roleeligibilityscheduleinstances?view=graph-rest-1.0
