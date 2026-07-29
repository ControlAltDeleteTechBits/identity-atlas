# Identity Atlas release-hardening test results

Date: 29 July 2026

Version: 0.14.0-preview.1 community release candidate

Tested commit: `50c8ed52220d4648c857d295a6371c3e35646f3e`

## Automated validation

PowerShell Pester tests: 41 passed, 0 failed

JavaScript worker tests: 8 passed, 0 failed

PSScriptAnalyzer: 0 findings

Source safety scan: 0 findings

Unsafe scanner fixture: rejected

Git exclusion validation: 6 of 6 unsafe paths ignored

Clean release archive import: passed

SHA256 verification: passed

Complete Git history scan: 6 commits passed, 0 findings

The clean build and release package completed successfully.

Release archive:

```text
IdentityAtlas-v0.14.0-preview.1.zip
SHA256: 0F6666B7C6A3A51B834C18355CC870FDDC823C04D70236152F39B48FDB0C09DC
```

The archive contained 66 entries and no forbidden generated-data directory or report file. The extracted module passed its safety scan and imported in a fresh PowerShell process with the four expected public commands.

## Local server validation

The hardened server was tested with the live tenant package on `127.0.0.1:8766`.

1. GET `/` returned 200.
2. HEAD requests returned 200 without a response body.
3. POST requests returned 405.
4. A path traversal request was rejected with 403.
5. An incomplete report package was rejected before the server started.
6. A test fixture was always rejected.
7. Cache prevention and browser security headers were present.
8. The listener remained bound to the loopback interface.

The local server supplied by the clean extracted package also served the existing live development-tenant report successfully on a separate test port. GET and HEAD returned 200, POST returned 405, caching was disabled and the Content Security Policy and frame protection headers were present. The test server was stopped after validation.

## Browser validation

The live report loaded in the in-app browser.

1. Settings opened successfully.
2. The security and data-handling guidance was displayed.
3. Report navigation remained functional after the asynchronous view-state fix.
4. No browser console errors were recorded in the clean validation tab.

## Live tenant evidence

The validated report identified itself as `LiveTenant` and retained the expected object, relationship and evidence counts.

The existing tenant export was upgraded to schema 1.1.0 and report version 0.13.0. It was not recollected because no reusable Microsoft Graph PowerShell context was available during this phase.

## Security checks covered

The test suite covers permission preflight, partial collector failures, token and secret exclusion, safe Graph hosts, error redaction, report-package markers, protected output paths, browser policy metadata and report schema validation.

This validation supports a community preview release. It is not an independent penetration test or a guarantee that a tenant report contains no sensitive administrative data.
