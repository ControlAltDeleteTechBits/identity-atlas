# Identity Atlas release-hardening test results

Date: 29 July 2026

Version: 0.14.0-preview.1 community release candidate

## Automated validation

PowerShell Pester tests: 41 passed, 0 failed

JavaScript worker tests: 8 passed, 0 failed

PSScriptAnalyzer: 0 findings

Source safety scan: 0 findings

Unsafe scanner fixture: rejected

Git exclusion validation: 6 of 6 unsafe paths ignored

Clean release archive import: passed

SHA256 verification: passed

The clean build and release package completed successfully.

Release archive:

```text
IdentityAtlas-v0.14.0-preview.1.zip
SHA256: EA46206F9687D6FB668ECD5AEDEE955D93E38A809F1523DC7737037DCB097A0B
```

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
