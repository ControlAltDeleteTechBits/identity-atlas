# Identity Atlas public release security test

Date: 30 July 2026

Version: `v0.14.0-preview.1`

Result: passed

Release candidate SHA256:

```text
D8B8D35B73370711438D4544A6D514648AD83A42D500FFCEE0B7D3830FDBA9E7
```

## Purpose

This test checks the source, complete Git history and release package before public visibility. It is intended to detect tenant evidence, credentials, unsafe write permissions, unexpected browser networking, risky workflow permissions and unintended authorship.

Run it from the repository root:

```powershell
.\tools\Test-IdentityAtlasPublicRelease.ps1 `
    -ReleasePath .\Release\IdentityAtlas-v0.14.0-preview.1.zip
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
10. Complete Git history content scan: 11 snapshots passed.
11. Release package checksum: passed.
12. Release archive content allowlist: passed.
13. Extracted package safety and module-manifest validation: passed.

The test found no tracked tenant report, user export, object identifier, tenant domain, access token, client secret, certificate, local user path or confidential screenshot.

All reviewed commits use Mark Oldham and Mark@controlaltdeletetechbits.co.uk as both author and committer. No additional contributor attribution is present.

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

1. Repository visibility remains private.
2. Workflow permissions are limited to `contents: read`.
3. Checkout does not retain Git credentials.
4. GitHub Actions dependencies are pinned to full commit identifiers.
5. `pull_request_target` is not used.
6. Dependency graph, Dependabot alerts, Dependabot security updates and grouped security updates are enabled.
7. Bug, feature and security-report routes recognise the checked-in templates.

The GitHub Free private-repository view does not expose the Community Profile or private vulnerability reporting controls. These must be rechecked after the repository becomes public.

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
