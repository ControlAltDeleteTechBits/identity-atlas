function New-AtlasReport {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Creates an in-memory report object and does not change external state.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TenantId,

        [Parameter(Mandatory)]
        [string] $TenantDisplayName,

        [Parameter(Mandatory)]
        [AtlasCollectionResult] $Collection,

        [object[]] $Collectors = @(),

        [ValidateSet('Core', 'Governance')]
        [string] $CollectionProfile = 'Core',

        [ValidateSet('LiveTenant', 'SampleFixture')]
        [string] $DataOrigin = 'LiveTenant'
    )

    $generatedAtUtc = [datetime]::UtcNow
    $manifest = [ordered] @{
        schemaVersion = '1.1.0'
        reportVersion = '0.15.1'
        dataOrigin = $DataOrigin
        collectionProfile = $CollectionProfile
        generatedAtUtc = $generatedAtUtc.ToString('o')
        tenant = [ordered] @{
            id = $TenantId
            displayName = $TenantDisplayName
        }
        coverage = [ordered] @{
            status = $Collection.Status
            warnings = @($Collection.Warnings)
            collectors = @($Collectors)
        }
        security = [ordered] @{
            readOnlyCollection = $true
            tokenDataSerialized = $false
            browserNetworkAccess = 'disabled'
            localServerBinding = 'loopbackOnly'
            containsTenantData = ($DataOrigin -eq 'LiveTenant')
        }
        counts = [ordered] @{
            nodes = $Collection.Nodes.Count
            edges = $Collection.Edges.Count
            evidence = $Collection.Evidence.Count
        }
        capabilities = @(
            'globalSearch'
            'objectDetails'
            'focusedGraph'
            'explainUserDirectoryRole'
            'explainUserAccess'
            'conditionalAccessPolicyGraph'
            'explainApplicationAccess'
            'mermaidExport'
            'evidenceMarkdownExport'
            'coverageExplorer'
            'relationshipFilter'
            'adminInsights'
            'reportComparison'
            'jsonCsvMarkdownExport'
            'svgGraphExport'
            'pngGraphExport'
            'workerSearchIndex'
            'debouncedSearch'
            'insightSeverity'
            'insightEvidenceExport'
            'adminReviewState'
            'reportTimeline'
            'evidenceFirstLayout'
            'pathCoverageConfidence'
            'remediationPowerShellSnippets'
            'permissionBlastRadius'
            'conditionalAccessImpactSimulator'
            'staleDeviceAndAuthHygiene'
            'dataOriginTagging'
            'sampleServingGuard'
            'deviceGraph'
            'authenticationMethodGraph'
            'conditionalAccessReferenceGraph'
            'comparisonHtmlReport'
            'relationshipGrouping'
            'objectBreadcrumbs'
            'pinnedObjects'
            'coverageDiagnostics'
            'releaseSecurityMetadata'
            'identityAtlasBrand'
            'nestedGroupPaths'
            'crossTenantAccessGraph'
            'applicationManagementPolicyGraph'
            'administrativeUnitGraph'
            'pimGroupsGraph'
            'entitlementManagementGraph'
            'accessReviewGraph'
        )
    }

    return [pscustomobject] @{
        manifest = $manifest
        nodes = @($Collection.Nodes)
        edges = @($Collection.Edges)
        evidence = @($Collection.Evidence)
    }
}
