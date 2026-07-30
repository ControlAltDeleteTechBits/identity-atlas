# Identity Atlas v0.14.0-preview.1

Identity Atlas is a local, read-only visual explorer for Microsoft Entra objects, relationships and access paths. This is the first community preview from Control Alt Delete Tech Bits.

Identity Atlas is an independent community project. It is not a Microsoft product and is not affiliated with, endorsed by or sponsored by Microsoft.

## Highlights

1. Collects users, groups, applications, service principals, directory roles, eligible role assignments, devices, authentication methods and Conditional Access resources through delegated Microsoft Graph read permissions.
2. Generates an offline single-page report with local search, filtering, relationship expansion and graph navigation.
3. Explains why a user or application has access using evidence-backed paths and coverage confidence.
4. Exports graph evidence as Mermaid, SVG, PNG and Markdown.
5. Adds severity, action plans, review states, remediation PowerShell snippets and per-finding evidence export.
6. Includes permission blast-radius, Conditional Access impact, stale-device and authentication-method hygiene views.
7. Supports report comparison, a change timeline, relationship grouping, breadcrumbs and tenant-specific pinned objects.

## Security boundaries

1. Default Microsoft Graph permissions are delegated and read only.
2. The collector sends GET requests to allow-listed Microsoft Graph hosts and API versions.
3. Authentication material is removed from recorded collector errors.
4. The browser report uses a restrictive Content Security Policy and makes no browser network requests.
5. The local server binds to `127.0.0.1`, refuses test fixture reports and rejects unsupported HTTP methods.
6. Generated reports and release archives are excluded from source control.

Reports contain sensitive administrative evidence. Store them in an access-controlled location, do not publish them and stop the local server after use.

## Install

1. Download `IdentityAtlas-v0.14.0-preview.1.zip`.
2. Download `IdentityAtlas-v0.14.0-preview.1-SHA256.txt`.
3. Verify the ZIP checksum.
4. Extract the ZIP into an access-controlled folder.
5. Import `IdentityAtlas.psd1` from PowerShell 7 or later.

```powershell
$expected = (Get-Content .\IdentityAtlas-v0.14.0-preview.1-SHA256.txt).Split(' ')[0]
$actual = (Get-FileHash .\IdentityAtlas-v0.14.0-preview.1.zip -Algorithm SHA256).Hash
if ($actual -ne $expected) {
    throw 'The downloaded Identity Atlas archive does not match its published checksum.'
}
```

The verified release candidate SHA256 is:

```text
D8B8D35B73370711438D4544A6D514648AD83A42D500FFCEE0B7D3830FDBA9E7
```

## Known limitations

1. Coverage is partial when Microsoft Graph permissions or the signed-in user’s Microsoft Entra role does not allow a resource to be read.
2. Directory-role access paths do not traverse nested group membership.
3. Conditional Access impact is based on collected evidence and does not replace Microsoft policy evaluation.
4. Reports contain tenant identifiers, user principal names, role assignments and other administrative evidence.
5. This preview has been tested in a development tenant, but wider tenant configurations may expose cases not present in that test.

## Feedback and security reports

Use GitHub Issues for reproducible bugs and feature requests after the repository is public.

Report suspected vulnerabilities privately by following `SECURITY.md`.

Support: Mark@controlaltdeletetechbits.co.uk

Donate: https://buymeacoffee.com/cadtb
