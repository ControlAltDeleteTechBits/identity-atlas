# Contributing to Identity Atlas

Identity Atlas welcomes useful, evidence-led contributions from Microsoft Entra administrators, PowerShell developers, security practitioners, technical writers and accessibility reviewers.

Control Alt Delete Tech Bits maintains the project. Mark Oldham has final responsibility for the project direction, security boundary, releases and decisions about whether a contribution is merged.

## Ways to contribute

1. Report a reproducible bug.
2. Suggest a focused feature.
3. Improve installation or administrator guidance.
4. Add or improve automated tests.
5. Improve accessibility or browser compatibility.
6. Add support for a Microsoft Graph resource.
7. Review a change against a real tenant without sharing tenant data.

Look for issues labelled `good first issue` or `help wanted` when those labels become available.

## Before starting

Open an issue before investing time in a large feature, new permission, schema change or new Microsoft Graph collector. Describe the administrator problem, the proposed behaviour and any new Microsoft Graph permission that may be required.

Small documentation corrections and narrowly scoped test improvements can be submitted directly as a pull request.

## Security and tenant data

Never include live tenant data in an issue, commit, pull request, test, screenshot or log.

Do not submit:

1. Tenant identifiers.
2. User principal names or email addresses from a tenant.
3. Object identifiers from a live tenant.
4. Access tokens or authentication context files.
5. Client secrets, passwords, certificates or private keys.
6. Generated Identity Atlas reports or exports.
7. Screenshots that contain administrative evidence.

Use reserved example domains such as `identityatlas.example` and obviously synthetic identifiers in tests.

Report security issues using the private process in `SECURITY.md`.

## Contribution process

1. Fork the repository into your GitHub account.
2. Create a branch with a short descriptive name.
3. Make one focused change.
4. Add or update tests.
5. Run the local validation commands.
6. Check that no tenant data or credentials are present.
7. Open a pull request using the supplied template.
8. Respond to review comments and update the branch when needed.

Do not commit directly to the project’s `main` branch. Do not add automated tools or assistants as commit authors. The human submitter is responsible for the change and its licence.

## Local validation

Run these commands from the repository root:

```powershell
$nodePath = (Get-Command node -ErrorAction Stop).Source
.\build.ps1 -NodePath $nodePath
.\tools\Test-IdentityAtlasRelease.ps1
```

The build must pass the PowerShell tests, JavaScript tests, manifest validation and PSScriptAnalyzer checks.

## PowerShell expectations

1. Use PowerShell 7 compatible syntax.
2. Use approved verbs for public commands.
3. Use `Set-StrictMode -Version Latest` in standalone tooling.
4. Keep Microsoft Graph access read only unless a separate design proposal is accepted.
5. Preserve the split between PowerShell collection and client-side exploration.
6. Continue collection safely when a Graph resource is unavailable.
7. Record partial coverage rather than presenting incomplete evidence as complete.
8. Add tests for security boundaries and error handling.

## Browser expectations

1. Keep the report offline after generation.
2. Do not add external scripts, fonts, analytics or telemetry.
3. Treat every tenant-provided value as untrusted text.
4. Preserve keyboard operation and visible focus states.
5. Test on a current Chromium-based browser.
6. Add or update JavaScript tests for graph traversal changes.

## Writing expectations

Use clear UK English. Explain administrator outcomes before implementation details. Avoid claims that Identity Atlas is a Microsoft product or has Microsoft endorsement.

## Licence

By submitting a contribution, you confirm that:

1. You have the right to submit it.
2. It can be distributed under the project’s MIT Licence.
3. Required third-party notices have been included.
4. You understand that acceptance is not guaranteed.

Human contributors whose work is merged remain visible in the Git commit history. Substantial contributions may also be acknowledged in release notes.
