function Connect-IdentityAtlas {
    [CmdletBinding()]
    param(
        [string[]] $Scopes,

        [ValidateSet('Core', 'Governance')]
        [string] $CollectionProfile = 'Core',

        [switch] $UseDeviceCode,

        [ValidateSet('Process', 'CurrentUser')]
        [string] $ContextScope = 'Process',

        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string] $ClientId,

        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string] $TenantId,

        [ValidateRange(30, 900)]
        [double] $ClientTimeout = 300
    )

    if (-not (Get-Command -Name Connect-MgGraph -ErrorAction SilentlyContinue)) {
        throw 'Microsoft.Graph.Authentication is not installed. Install it with Install-PSResource Microsoft.Graph.Authentication -Scope CurrentUser.'
    }

    if (-not $PSBoundParameters.ContainsKey('Scopes')) {
        $Scopes = Get-AtlasRecommendedScope -CollectionProfile $CollectionProfile
    }

    $parameters = @{
        Scopes = $Scopes
        NoWelcome = $true
        ContextScope = $ContextScope
        ClientTimeout = $ClientTimeout
        ErrorAction = 'Stop'
    }
    if ($UseDeviceCode) {
        $parameters.UseDeviceCode = $true
    }
    if ($ClientId) {
        $parameters.ClientId = $ClientId
    }
    if ($TenantId) {
        $parameters.TenantId = $TenantId
    }

    Connect-MgGraph @parameters
    $context = Get-MgContext
    if (-not $context -or -not $context.TenantId) {
        throw 'Microsoft Graph authentication completed without returning a tenant context.'
    }
    $permissionAssessment = Get-AtlasPermissionAssessment -ContextScope @($context.Scopes) -CollectionProfile $CollectionProfile
    $missingScope = Get-AtlasMissingRecommendedScope -MissingRequirement $permissionAssessment.missingRequirements
    if ($permissionAssessment.status -eq 'partial') {
        Write-Warning "The authenticated context is missing recommended delegated read scopes: $($missingScope -join ', '). Identity Atlas will mark affected collection as partial."
    }
    $additionalWriteScope = @(Get-AtlasAdditionalWriteScope -ContextScope @($context.Scopes))
    if ($additionalWriteScope.Count -gt 0) {
        Write-Warning (
            'The Microsoft Graph PowerShell context also contains delegated write permissions from an earlier consent: ' +
            "$($additionalWriteScope -join ', '). Identity Atlas does not request or use these scopes. " +
            'Review the Microsoft Graph Command Line Tools grant or use a dedicated application registration for a strict least-privilege context.'
        )
    }

    $script:IdentityAtlasCollectionProfile = $CollectionProfile

    return [pscustomobject] @{
        TenantId = $context.TenantId
        Account = $context.Account
        AuthType = $context.AuthType
        ClientId = if ($context.ClientId) { $context.ClientId } else { $ClientId }
        Scopes = @($context.Scopes)
        CollectionProfile = $CollectionProfile
        PermissionStatus = $permissionAssessment.status
        MissingScopes = $missingScope
        AdditionalWriteScopes = $additionalWriteScope
    }
}
