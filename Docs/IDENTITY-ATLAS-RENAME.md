# Identity Atlas rename record

Date: 29 July 2026

Release version: 0.14.0 preview

## Decision

The public product name is Identity Atlas.

Microsoft Entra ID remains the supported platform and is referenced descriptively in the interface, Microsoft Graph permission guidance and technical documentation.

## Public PowerShell surface

| Previous internal command | Identity Atlas command |
| --- | --- |
| Connect command | `Connect-IdentityAtlas` |
| Collection command | `Invoke-IdentityAtlas` |
| Export command | `Export-IdentityAtlas` |
| Comparison command | `Compare-IdentityAtlas` |

The module is imported with:

```powershell
Import-Module .\IdentityAtlas.psd1 -Force
```

No compatibility aliases are retained because the previous commands were not released publicly.

## Package and browser identifiers

1. Module name: `IdentityAtlas`
2. Report format: `IdentityAtlasReport`
3. Package marker: `.identity-atlas-report.json`
4. Package format version: `2.0.0`
5. Report version: `0.14.0`
6. Browser data runtime: `IdentityAtlasData`
7. Browser worker source: `IdentityAtlasWorkerSource`
8. Browser storage prefix: `identity-atlas`
9. Export filename prefix: `identity-atlas`

## Branding

The selected Space Grotesk and cartographic-globe direction is retained. The compact upper word now reads `IDENTITY`; the larger `ATLAS` word, diagonal cartographic cut, colour palette and globe remain.

The full wordmark and globe-only mark are self-contained SVG files. They do not load fonts, images or other resources from the internet.

## Tenant-data rule

`Invoke-IdentityAtlas` no longer includes a public sample-data parameter. It always requires an authenticated Microsoft Graph tenant context.

Synthetic objects are confined to the automated-test directory. Tests generate an ephemeral report in the system temporary directory and remove it when they finish.

The local server rejects every package whose data origin is `SampleFixture`. There is no override.

The project `Output` directory contains only the retained live tenant report.

## Live report migration

The existing live report was repackaged without recollecting Microsoft Graph data.

1. Data origin: `LiveTenant`
2. Objects: 498
3. Relationships: 120
4. Evidence records: 120
5. Report version: `0.14.0`

## Automated validation

1. PowerShell Pester tests: 34 passed, 0 failed.
2. JavaScript worker tests: 8 passed, 0 failed.
3. PSScriptAnalyzer findings: 0.
4. Old product identifiers in the current source and live package: 0.
5. Live report GET status: 200.
6. Non-GET request rejection: 405.
7. Sample fixture server test: rejected.
8. Browser console errors: 0.

The browser test covered the wordmark, Applications view, Settings view, report counts and live package origin. The renamed server remains bound to `127.0.0.1:8766`.
