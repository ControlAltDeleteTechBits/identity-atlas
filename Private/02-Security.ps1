function Get-AtlasPermissionAssessment {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string[]] $ContextScope
    )

    $grantedScope = @(
        $ContextScope |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { $_.Trim() }
    )

    $requirements = @(
        @{
            collector = 'users'
            recommended = 'User.Read.All'
            accepted = @('User.Read.All', 'User.ReadWrite.All', 'Directory.Read.All', 'Directory.ReadWrite.All')
        }
        @{
            collector = 'groups'
            recommended = 'Group.Read.All'
            accepted = @('Group.Read.All', 'Group.ReadWrite.All', 'Directory.Read.All', 'Directory.ReadWrite.All')
        }
        @{
            collector = 'devicesAndAuthentication'
            recommended = 'Device.Read.All'
            accepted = @('Device.Read.All', 'Device.ReadWrite.All', 'Directory.Read.All', 'Directory.ReadWrite.All')
        }
        @{
            collector = 'devicesAndAuthentication'
            recommended = 'UserAuthenticationMethod.Read.All'
            accepted = @('UserAuthenticationMethod.Read.All', 'UserAuthenticationMethod.ReadWrite.All')
        }
        @{
            collector = 'applications'
            recommended = 'Application.Read.All'
            accepted = @('Application.Read.All', 'Application.ReadWrite.All', 'Directory.Read.All', 'Directory.ReadWrite.All')
        }
        @{
            collector = 'conditionalAccess'
            recommended = 'Policy.Read.All'
            accepted = @('Policy.Read.All', 'Policy.ReadWrite.ConditionalAccess')
        }
        @{
            collector = 'directoryRoles'
            recommended = 'RoleManagement.Read.Directory'
            accepted = @('RoleManagement.Read.Directory', 'RoleManagement.Read.All', 'RoleManagement.ReadWrite.Directory')
        }
        @{
            collector = 'directoryRoles'
            recommended = 'RoleEligibilitySchedule.Read.Directory'
            accepted = @(
                'RoleEligibilitySchedule.Read.Directory'
                'RoleEligibilitySchedule.ReadWrite.Directory'
                'RoleManagement.Read.All'
                'RoleManagement.Read.Directory'
                'RoleManagement.ReadWrite.Directory'
            )
        }
    )

    $missing = [System.Collections.Generic.List[object]]::new()
    foreach ($requirement in $requirements) {
        $satisfied = @(
            $requirement.accepted |
                Where-Object { $grantedScope -contains $_ }
        ).Count -gt 0

        if (-not $satisfied) {
            $missing.Add(
                [pscustomobject] @{
                    collector = $requirement.collector
                    recommended = $requirement.recommended
                    accepted = @($requirement.accepted)
                }
            )
        }
    }

    return [pscustomobject] @{
        status = if ($missing.Count -eq 0) { 'complete' } else { 'partial' }
        grantedScopes = $grantedScope
        missingRequirements = @($missing)
        recommendedScopes = @($requirements.recommended | Sort-Object -Unique)
    }
}

function Get-AtlasMissingRecommendedScope {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object[]] $MissingRequirement
    )

    return @(
        $MissingRequirement |
            ForEach-Object { $_.recommended } |
            Sort-Object -Unique
    )
}

function New-AtlasPermissionPreflightResult {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Creates an in-memory collection result and does not change external state.'
    )]
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string[]] $ContextScope
    )

    $assessment = Get-AtlasPermissionAssessment -ContextScope $ContextScope
    $missingScope = Get-AtlasMissingRecommendedScope -MissingRequirement $assessment.missingRequirements
    $result = [AtlasCollectionResult]::new()
    $result.Status = $assessment.status
    $result.Metrics = @{
        grantedScopeCount = $assessment.grantedScopes.Count
        requiredScopeCount = $assessment.recommendedScopes.Count
        missingScopeCount = $assessment.missingRequirements.Count
        missingScopes = $missingScope
    }

    if ($assessment.missingRequirements.Count -gt 0) {
        $result.Warnings.Add(
            "The Microsoft Graph session is missing recommended delegated read scopes: $($missingScope -join ', '). Affected collectors will continue where Microsoft Graph permits and the report will remain partial."
        )
    }

    return $result
}

function Get-AtlasSafeErrorDetail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ErrorRecord] $ErrorRecord
    )

    $exception = $ErrorRecord.Exception
    $statusCode = $null
    if ($exception.PSObject.Properties['ResponseStatusCode']) {
        $statusCode = [int] $exception.ResponseStatusCode
    }
    elseif (
        $exception.PSObject.Properties['Response'] -and
        $exception.Response -and
        $exception.Response.PSObject.Properties['StatusCode']
    ) {
        $statusCode = [int] $exception.Response.StatusCode
    }

    $message = [string] $exception.Message
    $message = [regex]::Replace(
        $message,
        '(?i)\bBearer\s+[A-Za-z0-9._~+/=-]+',
        'Bearer [redacted]'
    )
    $message = [regex]::Replace(
        $message,
        '(?i)\b(access_token|client_secret|client_assertion|secretText|password|code)=([^&\s]+)',
        '$1=[redacted]'
    )
    $message = [regex]::Replace(
        $message,
        'https://[^\s''"<>]+',
        {
            param($match)
            try {
                $uri = [uri] $match.Value
                return "$($uri.Scheme)://$($uri.Host)$($uri.AbsolutePath)"
            }
            catch {
                return '[request URI]'
            }
        }
    )
    $message = ($message -replace '\s+', ' ').Trim()
    if ($message.Length -gt 400) {
        $message = "$($message.Substring(0, 397))..."
    }

    if ($statusCode) {
        return "HTTP $statusCode. $message"
    }
    return $message
}

function Invoke-AtlasCollector {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $DisplayName,

        [Parameter(Mandatory)]
        [scriptblock] $Collector
    )

    try {
        $result = & $Collector
        if ($null -eq $result) {
            throw "The '$Name' collector returned no result."
        }
        return $result
    }
    catch {
        $result = [AtlasCollectionResult]::new()
        $result.Status = 'partial'
        $result.Warnings.Add("$DisplayName could not be collected: $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
        $result.Metrics = @{
            requestCount = 0
            retryCount = 0
            failed = $true
        }
        return $result
    }
}

function Test-AtlasGraphUri {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Uri
    )

    if ($Uri -match '^/(v1\.0|beta)/') {
        return $true
    }

    $absoluteUri = $null
    if (-not [uri]::TryCreate($Uri, [System.UriKind]::Absolute, [ref] $absoluteUri)) {
        return $false
    }

    $allowedHost = @(
        'graph.microsoft.com'
        'graph.microsoft.us'
        'dod-graph.microsoft.us'
        'microsoftgraph.chinacloudapi.cn'
    )

    return (
        $absoluteUri.Scheme -eq 'https' -and
        -not $absoluteUri.UserInfo -and
        -not $absoluteUri.Fragment -and
        $allowedHost -contains $absoluteUri.DnsSafeHost -and
        $absoluteUri.AbsolutePath -match '^/(v1\.0|beta)/'
    )
}
