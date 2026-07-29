function Invoke-IdentityAtlas {
    [CmdletBinding()]
    param(
        [string] $OutputPath = (Join-Path (Get-Location) "IdentityAtlasReport-$([datetime]::Now.ToString('yyyyMMdd-HHmmss'))"),

        [switch] $OpenReport
    )

    if (-not (Get-Command -Name Get-MgContext -ErrorAction SilentlyContinue)) {
        throw 'Microsoft.Graph.Authentication is required for live collection. Run Connect-IdentityAtlas after installing the dependency.'
    }

    $context = Get-MgContext
    if (-not $context -or -not $context.TenantId) {
        throw 'No Microsoft Graph PowerShell session is active. Run Connect-IdentityAtlas first.'
    }

    $permissionPreflight = New-AtlasPermissionPreflightResult -ContextScope @($context.Scopes)
    $users = Invoke-AtlasCollector -Name 'users' -DisplayName 'Users' -Collector {
        Get-AtlasUser -TenantId $context.TenantId
    }
    $groups = Invoke-AtlasCollector -Name 'groups' -DisplayName 'Groups' -Collector {
        Get-AtlasGroup -TenantId $context.TenantId
    }
    $identityCollection = Merge-AtlasCollectionResult -Result @($permissionPreflight, $users, $groups)
    $devicesAndAuthentication = Invoke-AtlasCollector -Name 'devicesAndAuthentication' -DisplayName 'Devices and authentication methods' -Collector {
        Get-AtlasDeviceAndAuthentication -TenantId $context.TenantId -KnownNode @($identityCollection.Nodes)
    }
    $roles = Invoke-AtlasCollector -Name 'directoryRoles' -DisplayName 'Directory roles' -Collector {
        Get-AtlasDirectoryRole -TenantId $context.TenantId -KnownNode @($identityCollection.Nodes)
    }
    $applications = Invoke-AtlasCollector -Name 'applications' -DisplayName 'Applications' -Collector {
        Get-AtlasApplication -TenantId $context.TenantId -KnownNode @($identityCollection.Nodes)
    }
    $identityAndApplicationCollection = Merge-AtlasCollectionResult -Result @($identityCollection, $applications)
    $conditionalAccess = Invoke-AtlasCollector -Name 'conditionalAccess' -DisplayName 'Conditional Access policies' -Collector {
        Get-AtlasConditionalAccessPolicy -TenantId $context.TenantId -KnownNode @($identityAndApplicationCollection.Nodes)
    }
    $conditionalAccessReferences = Invoke-AtlasCollector -Name 'conditionalAccessReferences' -DisplayName 'Conditional Access references' -Collector {
        Get-AtlasConditionalAccessReference -TenantId $context.TenantId -KnownNode @($conditionalAccess.Nodes)
    }
    $collection = Merge-AtlasCollectionResult -Result @($identityCollection, $devicesAndAuthentication, $roles, $applications, $conditionalAccess, $conditionalAccessReferences)

    $collectors = @(
        @{ name = 'permissionPreflight'; status = $permissionPreflight.Status; metrics = $permissionPreflight.Metrics }
        @{ name = 'users'; status = $users.Status; metrics = $users.Metrics }
        @{ name = 'groups'; status = $groups.Status; metrics = $groups.Metrics }
        @{ name = 'devicesAndAuthentication'; status = $devicesAndAuthentication.Status; metrics = $devicesAndAuthentication.Metrics }
        @{ name = 'directoryRoles'; status = $roles.Status; metrics = $roles.Metrics }
        @{ name = 'applications'; status = $applications.Status; metrics = $applications.Metrics }
        @{ name = 'conditionalAccess'; status = $conditionalAccess.Status; metrics = $conditionalAccess.Metrics }
        @{ name = 'conditionalAccessReferences'; status = $conditionalAccessReferences.Status; metrics = $conditionalAccessReferences.Metrics }
    )
    $report = New-AtlasReport -TenantId $context.TenantId -TenantDisplayName $context.TenantId -Collection $collection -Collectors $collectors -DataOrigin LiveTenant

    $indexFile = Write-AtlasReport -Report $report -OutputPath $OutputPath
    if ($OpenReport) {
        Start-Process -FilePath $indexFile.FullName
    }

    return [pscustomobject] @{
        OutputPath = $indexFile.DirectoryName
        IndexPath = $indexFile.FullName
        NodeCount = $report.manifest.counts.nodes
        EdgeCount = $report.manifest.counts.edges
        EvidenceCount = $report.manifest.counts.evidence
        CoverageStatus = $report.manifest.coverage.status
    }
}
