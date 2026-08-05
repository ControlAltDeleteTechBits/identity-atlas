function Invoke-IdentityAtlas {
    [CmdletBinding()]
    param(
        [string] $OutputPath = (Join-Path (Get-Location) "IdentityAtlasReport-$([datetime]::Now.ToString('yyyyMMdd-HHmmss'))"),

        [switch] $OpenReport,

        [ValidateSet('Auto', 'Core', 'Governance')]
        [string] $CollectionProfile = 'Auto',

        [switch] $SkipSlowCollectors,

        [ValidateSet('GroupMembersAndOwners', 'DeviceOwners', 'AuthenticationMethods', 'ApplicationRoleAssignments', 'ApplicationOwners')]
        [string[]] $SkipCollector = @(),

        [ValidateRange(1, 20)]
        [int] $BatchSize = 10,

        [ValidateRange(1024, 65535)]
        [int] $Port = 8766,

        [ValidateRange(0, 50)]
        [int] $PortSearchLimit = 20
    )

    if (-not (Get-Command -Name Get-MgContext -ErrorAction SilentlyContinue)) {
        throw 'Microsoft.Graph.Authentication is required for live collection. Run Connect-IdentityAtlas after installing the dependency.'
    }

    $context = Get-MgContext
    if (-not $context -or -not $context.TenantId) {
        throw 'No Microsoft Graph PowerShell session is active. Run Connect-IdentityAtlas first.'
    }

    if ($CollectionProfile -eq 'Auto') {
        $storedProfile = Get-Variable -Name IdentityAtlasCollectionProfile -Scope Script -ErrorAction SilentlyContinue
        $CollectionProfile = if ($storedProfile -and $storedProfile.Value) { $storedProfile.Value } else { 'Core' }
    }

    $skippedCollector = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    foreach ($collectorName in $SkipCollector) {
        [void] $skippedCollector.Add($collectorName)
    }
    if ($SkipSlowCollectors) {
        foreach ($collectorName in @('GroupMembersAndOwners', 'DeviceOwners', 'AuthenticationMethods', 'ApplicationRoleAssignments', 'ApplicationOwners')) {
            [void] $skippedCollector.Add($collectorName)
        }
    }

    $stepCount = if ($CollectionProfile -eq 'Governance') { 13 } else { 9 }
    $effectiveBatchSize = $BatchSize
    $progressSummary = $null
    Initialize-AtlasProgress `
        -StepCount $stepCount `
        -CollectionProfile $CollectionProfile `
        -SkippedCollector @($skippedCollector) | Out-Null

    try {
        $permissionPreflight = New-AtlasPermissionPreflightResult -ContextScope @($context.Scopes) -CollectionProfile $CollectionProfile
        $users = Invoke-AtlasCollector -Name 'users' -DisplayName 'Users' -Step 1 -Collector {
            Get-AtlasUser -TenantId $context.TenantId
        }
        $groups = Invoke-AtlasCollector -Name 'groups' -DisplayName 'Groups' -Step 2 -Collector {
            Get-AtlasGroup `
                -TenantId $context.TenantId `
                -SkipMembersAndOwners:$skippedCollector.Contains('GroupMembersAndOwners')
        }
        $identityCollection = Merge-AtlasCollectionResult -Result @($permissionPreflight, $users, $groups)
        $devicesAndAuthentication = Invoke-AtlasCollector -Name 'devicesAndAuthentication' -DisplayName 'Devices and authentication methods' -Step 3 -Collector {
            Get-AtlasDeviceAndAuthentication `
                -TenantId $context.TenantId `
                -KnownNode @($identityCollection.Nodes) `
                -SkipDeviceOwners:$skippedCollector.Contains('DeviceOwners') `
                -SkipAuthenticationMethods:$skippedCollector.Contains('AuthenticationMethods') `
                -BatchSize $effectiveBatchSize
        }
        $roles = Invoke-AtlasCollector -Name 'directoryRoles' -DisplayName 'Directory roles' -Step 4 -Collector {
            Get-AtlasDirectoryRole -TenantId $context.TenantId -KnownNode @($identityCollection.Nodes)
        }
        $applications = Invoke-AtlasCollector -Name 'applications' -DisplayName 'Applications' -Step 5 -Collector {
            Get-AtlasApplication `
                -TenantId $context.TenantId `
                -KnownNode @($identityCollection.Nodes) `
                -SkipAppRoleAssignments:$skippedCollector.Contains('ApplicationRoleAssignments') `
                -SkipOwners:$skippedCollector.Contains('ApplicationOwners') `
                -BatchSize $effectiveBatchSize
        }
        $identityAndApplicationCollection = Merge-AtlasCollectionResult -Result @($identityCollection, $applications)
        $applicationManagementPolicies = Invoke-AtlasCollector -Name 'applicationManagementPolicies' -DisplayName 'Application management policies' -Step 6 -Collector {
            Get-AtlasApplicationManagementPolicy -TenantId $context.TenantId -KnownNode @($identityAndApplicationCollection.Nodes)
        }
        $crossTenantAccess = Invoke-AtlasCollector -Name 'crossTenantAccess' -DisplayName 'Cross-tenant access settings' -Step 7 -Collector {
            Get-AtlasCrossTenantAccess -TenantId $context.TenantId
        }
        $conditionalAccess = Invoke-AtlasCollector -Name 'conditionalAccess' -DisplayName 'Conditional Access policies' -Step 8 -Collector {
            Get-AtlasConditionalAccessPolicy -TenantId $context.TenantId -KnownNode @($identityAndApplicationCollection.Nodes)
        }
        $conditionalAccessReferences = Invoke-AtlasCollector -Name 'conditionalAccessReferences' -DisplayName 'Conditional Access references' -Step 9 -Collector {
            Get-AtlasConditionalAccessReference -TenantId $context.TenantId -KnownNode @($conditionalAccess.Nodes)
        }
        $coreCollection = Merge-AtlasCollectionResult -Result @(
            $identityCollection
            $devicesAndAuthentication
            $roles
            $applications
            $applicationManagementPolicies
            $crossTenantAccess
            $conditionalAccess
            $conditionalAccessReferences
        )

        $governanceResults = @()
        if ($CollectionProfile -eq 'Governance') {
            $administrativeUnits = Invoke-AtlasCollector -Name 'administrativeUnits' -DisplayName 'Administrative Units' -Step 10 -Collector {
                Get-AtlasAdministrativeUnit -TenantId $context.TenantId -KnownNode @($coreCollection.Nodes) -KnownEdge @($roles.Edges)
            }
            $pimGroups = Invoke-AtlasCollector -Name 'pimGroups' -DisplayName 'PIM for Groups assignments' -Step 11 -Collector {
                Get-AtlasPrivilegedGroupAssignment -TenantId $context.TenantId -KnownNode @($coreCollection.Nodes)
            }
            $governanceFoundation = Merge-AtlasCollectionResult -Result @($coreCollection, $administrativeUnits, $pimGroups)
            $entitlementManagement = Invoke-AtlasCollector -Name 'entitlementManagement' -DisplayName 'Entitlement Management' -Step 12 -Collector {
                Get-AtlasEntitlementManagement -TenantId $context.TenantId -KnownNode @($governanceFoundation.Nodes)
            }
            $governanceWithEntitlements = Merge-AtlasCollectionResult -Result @($governanceFoundation, $entitlementManagement)
            $accessReviews = Invoke-AtlasCollector -Name 'accessReviews' -DisplayName 'Access Reviews' -Step 13 -Collector {
                Get-AtlasAccessReview -TenantId $context.TenantId -KnownNode @($governanceWithEntitlements.Nodes)
            }
            $governanceResults = @($administrativeUnits, $pimGroups, $entitlementManagement, $accessReviews)
        }
        $collection = Merge-AtlasCollectionResult -Result (@($coreCollection) + $governanceResults)

        $collectors = @(
            @{ name = 'permissionPreflight'; status = $permissionPreflight.Status; metrics = $permissionPreflight.Metrics }
            @{ name = 'users'; status = $users.Status; metrics = $users.Metrics }
            @{ name = 'groups'; status = $groups.Status; metrics = $groups.Metrics }
            @{ name = 'devicesAndAuthentication'; status = $devicesAndAuthentication.Status; metrics = $devicesAndAuthentication.Metrics }
            @{ name = 'directoryRoles'; status = $roles.Status; metrics = $roles.Metrics }
            @{ name = 'applications'; status = $applications.Status; metrics = $applications.Metrics }
            @{ name = 'applicationManagementPolicies'; status = $applicationManagementPolicies.Status; metrics = $applicationManagementPolicies.Metrics }
            @{ name = 'crossTenantAccess'; status = $crossTenantAccess.Status; metrics = $crossTenantAccess.Metrics }
            @{ name = 'conditionalAccess'; status = $conditionalAccess.Status; metrics = $conditionalAccess.Metrics }
            @{ name = 'conditionalAccessReferences'; status = $conditionalAccessReferences.Status; metrics = $conditionalAccessReferences.Metrics }
        )
        if ($CollectionProfile -eq 'Governance') {
            $collectors += @(
                @{ name = 'administrativeUnits'; status = $administrativeUnits.Status; metrics = $administrativeUnits.Metrics }
                @{ name = 'pimGroups'; status = $pimGroups.Status; metrics = $pimGroups.Metrics }
                @{ name = 'entitlementManagement'; status = $entitlementManagement.Status; metrics = $entitlementManagement.Metrics }
                @{ name = 'accessReviews'; status = $accessReviews.Status; metrics = $accessReviews.Metrics }
            )
        }
        $report = New-AtlasReport -TenantId $context.TenantId -TenantDisplayName $context.TenantId -Collection $collection -Collectors $collectors -DataOrigin LiveTenant -CollectionProfile $CollectionProfile
        $indexFile = Write-AtlasReport -Report $report -OutputPath $OutputPath
        $progressSummary = Complete-AtlasProgress -Status Complete -OutputPath $indexFile.DirectoryName
    }
    catch [System.Management.Automation.PipelineStoppedException] {
        [void] (Complete-AtlasProgress -Status Cancelled -OutputPath $OutputPath)
        throw
    }
    catch [System.OperationCanceledException] {
        [void] (Complete-AtlasProgress -Status Cancelled -OutputPath $OutputPath)
        throw
    }
    catch {
        [void] (Complete-AtlasProgress -Status Failed -OutputPath $OutputPath)
        throw
    }

    $server = $null
    if ($OpenReport) {
        $server = Start-AtlasReportServer `
            -ReportRoot $indexFile.DirectoryName `
            -Port $Port `
            -PortSearchLimit $PortSearchLimit `
            -OpenBrowser
    }

    return [pscustomobject] @{
        OutputPath = $indexFile.DirectoryName
        IndexPath = $indexFile.FullName
        NodeCount = $report.manifest.counts.nodes
        EdgeCount = $report.manifest.counts.edges
        EvidenceCount = $report.manifest.counts.evidence
        CoverageStatus = $report.manifest.coverage.status
        CollectionProfile = $CollectionProfile
        Duration = $progressSummary.Duration
        RequestCount = $progressSummary.RequestCount
        RetryCount = $progressSummary.RetryCount
        SkippedCollectors = @($progressSummary.SkippedCollectors)
        ReportUrl = if ($server) { $server.Url } else { $null }
        ServerProcessId = if ($server) { $server.ProcessId } else { $null }
    }
}
