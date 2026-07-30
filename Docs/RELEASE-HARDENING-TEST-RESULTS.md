# Identity Atlas release-hardening test results

Date: 29 July 2026

Version: 0.14.0-preview.1 community release candidate

Tested commit: `f2bc942d784a6b8dbef3606e6495e32b86fe9d66`

## Automated validation

PowerShell Pester tests: 44 passed, 0 failed

JavaScript worker tests: 8 passed, 0 failed

PSScriptAnalyzer: 0 findings

Source safety scan: 0 findings

Unsafe scanner fixture: rejected

Git exclusion validation: 6 of 6 unsafe paths ignored

Clean release archive import: passed

SHA256 verification: passed

Complete Git history scan: 10 commits passed, 0 findings

The clean build and release package completed successfully.

Release archive:

```text
IdentityAtlas-v0.14.0-preview.1.zip
SHA256: D8B8D35B73370711438D4544A6D514648AD83A42D500FFCEE0B7D3830FDBA9E7
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

The final extracted-package validation generated a new report identified as `LiveTenant`. It contained 460 objects, 64 relationships and 64 evidence records.

The report used schema 1.1.0 and report version 0.14.0. Coverage was partial with 12 warnings caused by expected HTTP 403 responses or an unresolved role definition. No internal parameter-binding error remained, no authentication material was found and the process-scoped Graph context was disconnected after collection.

The live rehearsal found and corrected two pre-release defects:

1. A complete permission assessment attempted to read an optional property from an empty collection under PowerShell strict mode.
2. A downstream relationship collector rejected an empty upstream node collection after Conditional Access collection returned HTTP 403.

The final browser package also explains that Conditional Access collection requires both Policy.Read.All and a supported Microsoft Entra role.

## Security checks covered

The test suite covers permission preflight, partial collector failures, token and secret exclusion, safe Graph hosts, error redaction, report-package markers, protected output paths, browser policy metadata and report schema validation.

This validation supports a community preview release. It is not an independent penetration test or a guarantee that a tenant report contains no sensitive administrative data.
