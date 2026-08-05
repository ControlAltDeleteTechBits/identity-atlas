# Dedicated Microsoft Graph application

Identity Atlas can use its own Microsoft Entra application registration instead of the shared Microsoft Graph Command Line Tools application.

This is the recommended configuration for organisations that require a strict least privilege consent boundary.

## Create the application

1. Open the Microsoft Entra admin centre.
2. Open Identity, Applications, App registrations.
3. Select New registration.
4. Enter `Identity Atlas PowerShell` as the name.
5. Select Accounts in this organisational directory only.
6. Under Redirect URI, select Public client/native and enter `http://localhost`.
7. Select Register.
8. Record the Application (client) ID and Directory (tenant) ID.
9. Open Authentication for the new application.
10. Under Mobile and desktop applications, add `http://localhost` if it is not already present.
11. Enable Allow public client flows when device-code authentication will be used.
12. Do not create a client secret or certificate for delegated Identity Atlas use.

The Microsoft Graph PowerShell authentication documentation also recommends restricting who can use a privileged custom application:

1. Open Enterprise applications and select Identity Atlas PowerShell.
2. Open Properties.
3. Set Assignment required to Yes.
4. Open Users and groups.
5. Assign only the administrators permitted to collect Identity Atlas reports.

Microsoft reference: https://learn.microsoft.com/powershell/microsoftgraph/authentication-commands

## Connect Identity Atlas

Use the recorded identifiers:

```powershell
Connect-IdentityAtlas `
    -UseDeviceCode `
    -ClientId '<application-client-id>' `
    -TenantId '<directory-tenant-id>' `
    -ContextScope Process
```

Identity Atlas requests its delegated read scopes during sign-in. Select the Governance profile only when Administrative Units, PIM for Groups, Entitlement Management and Access Reviews are required:

```powershell
Connect-IdentityAtlas `
    -UseDeviceCode `
    -ClientId '<application-client-id>' `
    -TenantId '<directory-tenant-id>' `
    -ContextScope Process `
    -CollectionProfile Governance
```

Review the consent screen before accepting it. Identity Atlas does not request delegated write permissions, application permissions, a client secret or an application certificate.

## Validate the context

```powershell
$context = Get-MgContext
$context | Select-Object ClientId, TenantId, Account, AuthType, ContextScope
$context.Scopes | Sort-Object
```

Confirm that ClientId matches the dedicated application and that the returned permissions are read only.

Disconnect when collection is complete:

```powershell
Disconnect-MgGraph
```
