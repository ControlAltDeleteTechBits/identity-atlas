# Identity Atlas v0.16.0 preview 1

Release date: 5 August 2026

Publisher: Control Alt Delete Tech Bits

Identity Atlas v0.16.0 improves the normal administrator experience from collection through to reviewing the local report. PowerShell now shows continuous collection status instead of appearing idle during large tenant exports. When collection finishes, `-OpenReport` serves the generated live tenant report on the local loopback interface and opens it in the default browser.

## Collection progress

The progress display includes:

1. The active collector and its position in the Core or Governance profile.
2. Current item and total item counts for per-object work.
3. Cumulative Microsoft Graph request and retry totals.
4. Collected object, relationship and evidence totals.
5. Elapsed collection time.

Microsoft Graph throttling and temporary service errors produce a visible warning with the HTTP condition, retry delay and attempt number.

## Bounded Graph batches

Authentication method requests are grouped into bounded Microsoft Graph JSON batches instead of issuing one blocking request after another for every user. Application role assignments and owner lookups use the same approach. The default batch size is ten and administrators can select a value from 1 to 20 with `-BatchSize`.

Every resource subrequest remains GET. The module permits POST only to the Microsoft Graph v1.0 batch transport and validates every contained URI before sending it.

## Reduced collection options

`-SkipSlowCollectors` omits the slower per-object group, device, authentication method and application relationship calls. Granular selection is available through `-SkipCollector` with these values:

1. `GroupMembersAndOwners`
2. `DeviceOwners`
3. `AuthenticationMethods`
4. `ApplicationRoleAssignments`
5. `ApplicationOwners`

Skipped work is never presented as complete. The generated report records partial coverage, a readable warning and collector metrics identifying each omission.

## Cancellation and report opening

Ctrl+C stops the active collection and prints a summary with elapsed time, completed stages and collected totals. An incomplete report package is not written.

After a successful collection, `-OpenReport` starts the packaged loopback server on `127.0.0.1`. Port 8766 is used by default. If it is occupied, Identity Atlas checks the next permitted ports and returns the selected URL and server process ID in the command result.

## Example

```powershell
Import-Module IdentityAtlas
Connect-IdentityAtlas -UseDeviceCode -ContextScope Process
$result = Invoke-IdentityAtlas `
    -OutputPath "$env:USERPROFILE\Documents\IdentityAtlasReport" `
    -OpenReport

$result | Select-Object OutputPath, ReportUrl, ServerProcessId, Duration, RequestCount, RetryCount
```

For a deliberately reduced collection:

```powershell
Invoke-IdentityAtlas `
    -OutputPath "$env:USERPROFILE\Documents\IdentityAtlasReport" `
    -OpenReport `
    -SkipSlowCollectors
```

## Validation status

1. PowerShell tests: 64 passed.
2. JavaScript graph worker tests: 14 passed.
3. PowerShell Script Analyzer: no findings.
4. Tenant-data, credential and secret scans: no findings.
5. Public release security checks: 13 passed.
6. PowerShell Gallery package checks: 16 passed, including isolated discovery, save and clean import.
7. Browser interaction checks against existing live development tenant data: passed with no console errors.
8. The JSON batch transport passed automated mocked Graph tests but did not receive a fresh live Core collection during this release cycle. It remains preview functionality requiring community field testing.
