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
        [int] $PortSearchLimit = 20,

        [switch] $Checkpoint,

        [switch] $Resume,

        [string] $SettingsPath,

        [string] $SaveSettingsPath,

        [switch] $IncludeConsent
    )

    if (-not (Get-Command -Name Get-MgContext -ErrorAction SilentlyContinue)) {
        throw 'Microsoft.Graph.Authentication is required for live collection. Run Connect-IdentityAtlas after installing the dependency.'
    }

    $context = Get-MgContext
    if (-not $context -or -not $context.TenantId) {
        throw 'No Microsoft Graph PowerShell session is active. Run Connect-IdentityAtlas first.'
    }

    if ($SettingsPath) {
        $settings = Get-Content -LiteralPath $SettingsPath -Raw | ConvertFrom-Json -AsHashtable
        foreach ($key in $settings.Keys) {
            if ($key -notin @('CollectionProfile', 'SkipCollector', 'BatchSize', 'IncludeConsent')) { throw "Unsupported saved setting: $key" }
        }
        if (-not $PSBoundParameters.ContainsKey('CollectionProfile') -and $settings.ContainsKey('CollectionProfile')) {
            if ($settings.CollectionProfile -notin @('Core', 'Governance')) { throw 'Invalid saved collection profile.' }
            $CollectionProfile = $settings.CollectionProfile
        }
        if (-not $PSBoundParameters.ContainsKey('BatchSize') -and $settings.ContainsKey('BatchSize')) {
            if ($settings.BatchSize -notin 1..20) { throw 'Saved BatchSize must be from 1 to 20.' }
            $BatchSize = $settings.BatchSize
        }
        if (-not $PSBoundParameters.ContainsKey('SkipCollector') -and $settings.ContainsKey('SkipCollector')) {
            foreach ($name in $settings.SkipCollector) { if ($name -notin @('GroupMembersAndOwners', 'DeviceOwners', 'AuthenticationMethods', 'ApplicationRoleAssignments', 'ApplicationOwners')) { throw "Invalid saved collector: $name" } }
            $SkipCollector = @($settings.SkipCollector)
        }
        if (-not $PSBoundParameters.ContainsKey('IncludeConsent') -and $settings.ContainsKey('IncludeConsent')) {
            if ($settings.IncludeConsent -isnot [bool]) { throw 'Saved IncludeConsent must be a JSON boolean.' }
            $IncludeConsent = $settings.IncludeConsent
        }
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
    if ($IncludeConsent) { $stepCount++ }
    if ($SaveSettingsPath) {
        if (Test-Path -LiteralPath $SaveSettingsPath) { throw 'Settings file already exists. Choose a new settings filename.' }
        Write-AtlasTextFile -Path ([IO.Path]::GetFullPath($SaveSettingsPath)) -Content (@{ CollectionProfile = $CollectionProfile; SkipCollector = @($skippedCollector); BatchSize = $BatchSize; IncludeConsent = [bool]$IncludeConsent } | ConvertTo-Json)
    }
    $effectiveBatchSize = $BatchSize
    $progressSummary = $null
    Initialize-AtlasProgress `
        -StepCount $stepCount `
        -CollectionProfile $CollectionProfile `
        -SkippedCollector @($skippedCollector) | Out-Null

    try {
        $script:AtlasCheckpoint = $null
        if ($Checkpoint -or $Resume) {
            $implementationHashes = @(foreach ($folder in @('Private', 'Public')) {
                Get-ChildItem -LiteralPath (Join-Path $moduleRoot $folder) -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object {
                    "$folder/$($_.Name):$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
                }
            })
            $checkpointIdentity = [ordered]@{
                tenant = $context.TenantId; account = $context.Account; client = $context.ClientId
                scopes = @($context.Scopes | Sort-Object); profile = $CollectionProfile
                skipped = @($skippedCollector | Sort-Object); batchSize = $BatchSize; consent = [bool]$IncludeConsent; version = '2.0.0'
                implementation = Get-AtlasStableId -InputString ($implementationHashes -join '|')
            }
            Initialize-AtlasCheckpoint -Path "$OutputPath.checkpoint" -Identity $checkpointIdentity -Resume:$Resume
        }
        $permissionPreflight = New-AtlasPermissionPreflightResult -ContextScope @($context.Scopes) -CollectionProfile $CollectionProfile -IncludeConsent:$IncludeConsent
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
        $consent = $null
        if ($IncludeConsent) {
            $consent = Invoke-AtlasCollector -Name 'delegatedConsent' -DisplayName 'Delegated consent grants' -Step $stepCount -Collector {
                Get-AtlasConsent -TenantId $context.TenantId -KnownNode @($collection.Nodes)
            }
            $collection = Merge-AtlasCollectionResult -Result @($collection, $consent)
        }

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
        if ($IncludeConsent) { $report.manifest.coverage.collectors += @{ name = 'delegatedConsent'; status = $consent.Status; metrics = $consent.Metrics } }
        if ($script:AtlasCheckpoint -and $script:AtlasCheckpoint.Reused.Count) {
            $report.manifest.coverage.status = 'partial'
            $report.manifest.coverage.warnings += 'Resumed collection contains earlier evidence. Review individual timestamps; this is not a single-time snapshot.'
            $report.manifest['resumedCollectors'] = @($script:AtlasCheckpoint.Reused)
        }
        $indexFile = Write-AtlasReport -Report $report -OutputPath $OutputPath
        $progressSummary = Complete-AtlasProgress -Status Complete -OutputPath $indexFile.DirectoryName
    }
    catch [System.Management.Automation.PipelineStoppedException] {
        [void] (Complete-AtlasProgress -Status Cancelled -OutputPath $OutputPath)
        Write-AtlasInterruptedCollectionGuidance
        throw
    }
    catch [System.OperationCanceledException] {
        [void] (Complete-AtlasProgress -Status Cancelled -OutputPath $OutputPath)
        Write-AtlasInterruptedCollectionGuidance
        throw
    }
    catch {
        [void] (Complete-AtlasProgress -Status Failed -OutputPath $OutputPath)
        Write-AtlasInterruptedCollectionGuidance
        throw
    }
    finally {
        # Ctrl+C can stop the pipeline before the catch block can run output
        # cmdlets. Direct host calls in finally still work in an interactive
        # host; do not call functions or cmdlets on this fallback path.
        if ($script:IdentityAtlasProgressContext) {
            $interrupted = $script:IdentityAtlasProgressContext
            $interrupted.Stopwatch.Stop()
            $elapsedText = $interrupted.Stopwatch.Elapsed.ToString('hh\:mm\:ss')
            $Host.UI.WriteLine("Identity Atlas collection interrupted after $elapsedText | Collector: $($interrupted.CollectorDisplayName) | Completed stages $($interrupted.CompletedStepCount)/$($interrupted.StepCount) | Requests $($interrupted.RequestCount) | Retries $($interrupted.RetryCount).")
            $Host.UI.WriteLine("Processed $($interrupted.NodeCount) objects, $($interrupted.EdgeCount) relationships and $($interrupted.EvidenceCount) evidence records. No completed report is being returned by this run.")
            if ($script:AtlasCheckpoint) {
                $Host.UI.WriteLine("Checkpoint folder: $($script:AtlasCheckpoint.Root). Re-run the original command with -Resume and the same output folder, options, account and module within 24 hours. Completed collectors can be reused; interrupted or partial collectors start again. Keep checkpoint data private.")
            }
            else {
                $Host.UI.WriteLine('No checkpoint is active. Start a new collection; use -Checkpoint to retain completed collectors for resume.')
            }
            $script:IdentityAtlasProgressContext = $null
        }
        $script:AtlasCheckpoint = $null
    }

    $completion = Get-AtlasCompletionSummary -Report $report -ReportPath $indexFile.DirectoryName -SkippedCollector @($skippedCollector)
    Write-Information "Report saved: $($indexFile.FullName) | Coverage: $($report.manifest.coverage.status) | $($report.manifest.counts.nodes) unique objects, $($report.manifest.counts.edges) relationships, $($report.manifest.counts.evidence) evidence records." -InformationAction Continue
    Write-Information "Complete collectors: $($completion.CompleteCollectors -join ', ')." -InformationAction Continue
    if ($completion.IncompleteCollectors.Count) {
        Write-Information "Incomplete collectors: $($completion.IncompleteCollectors -join ', '). Coverage warnings: $($completion.WarningCount)." -InformationAction Continue
    }
    if ($completion.SkippedCollectors.Count) { Write-Information "Skipped: $($completion.SkippedCollectors -join ', ')." -InformationAction Continue }
    foreach ($action in $completion.NextActions) { Write-Information "Next: $action" -InformationAction Continue }
    Write-Information "Reopen this report: $($completion.ReopenCommand)" -InformationAction Continue
    $server = $null
    if ($OpenReport) {
        try {
            $server = Start-AtlasReportServer `
            -ReportRoot $indexFile.DirectoryName `
            -Port $Port `
            -PortSearchLimit $PortSearchLimit `
            -OpenBrowser
        }
        catch {
            if ($_.Exception -is [System.OperationCanceledException] -or $_.Exception -is [System.Management.Automation.PipelineStoppedException]) { throw }
            Write-Warning "The report was saved, but could not be opened automatically. Reopen it using: $($completion.ReopenCommand)"
        }
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
        CompleteCollectors = $completion.CompleteCollectors
        IncompleteCollectors = $completion.IncompleteCollectors
        NextActions = $completion.NextActions
        ReopenCommand = $completion.ReopenCommand
        ReportUrl = if ($server) { $server.Url } else { $null }
        ServerProcessId = if ($server) { $server.ProcessId } else { $null }
    }
}
