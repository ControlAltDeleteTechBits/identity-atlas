function Connect-IdentityAtlas {
    [CmdletBinding()]
    param(
        [string[]] $Scopes,

        [ValidateSet('Core', 'Governance')]
        [string] $CollectionProfile = 'Core',

        [switch] $UseDeviceCode,

        [ValidateSet('Process', 'CurrentUser')]
        [string] $ContextScope = 'Process',

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

    $script:IdentityAtlasCollectionProfile = $CollectionProfile

    return [pscustomobject] @{
        TenantId = $context.TenantId
        Account = $context.Account
        AuthType = $context.AuthType
        Scopes = @($context.Scopes)
        CollectionProfile = $CollectionProfile
        PermissionStatus = $permissionAssessment.status
        MissingScopes = $missingScope
    }
}
