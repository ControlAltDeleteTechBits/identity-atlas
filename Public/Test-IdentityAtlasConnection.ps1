function Test-IdentityAtlasConnection {
    <#
    .SYNOPSIS
    Checks the local Graph context and consent without collecting tenant data.
    .DESCRIPTION
    A context and consent check cannot prove endpoint access, administrator roles
    or licensing. Those checks occur during collection and appear as coverage.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('Core', 'Governance')] [string] $CollectionProfile = 'Core',
        [switch] $IncludeConsent
    )
    $context = if (Get-Command Get-MgContext -ErrorAction SilentlyContinue) { Get-MgContext } else { $null }
    if (-not $context -or -not $context.TenantId) {
        return [pscustomobject] @{ Connected = $false; Guidance = 'Run Connect-IdentityAtlas in this PowerShell session.' }
    }
    $assessment = Get-AtlasPermissionAssessment -ContextScope @($context.Scopes) -CollectionProfile $CollectionProfile -IncludeConsent:$IncludeConsent
    [pscustomobject] @{
        Connected = $true
        TenantId = $context.TenantId
        Account = $context.Account
        AuthType = $context.AuthType
        CollectionProfile = $CollectionProfile
        PermissionStatus = $assessment.status
        IncludeConsent = [bool] $IncludeConsent
        EndpointAccess = $assessment.endpointAccess
        MissingRequirements = @($assessment.missingRequirements)
        MissingScopes = @(Get-AtlasMissingRecommendedScope -MissingRequirement $assessment.missingRequirements)
        AdditionalWriteScopes = @(Get-AtlasAdditionalWriteScope -ContextScope @($context.Scopes))
        Guidance = 'Local context checked only. Endpoint access, administrator roles and licensing remain unverified until collection.'
    }
}
