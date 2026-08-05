if (-not (Get-Variable -Name IdentityAtlasProgressContext -Scope Script -ErrorAction SilentlyContinue)) {
    $script:IdentityAtlasProgressContext = $null
}

function Get-AtlasElapsedText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Diagnostics.Stopwatch] $Stopwatch
    )

    return $Stopwatch.Elapsed.ToString('hh\:mm\:ss')
}

function Initialize-AtlasProgress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, 30)]
        [int] $StepCount,

        [Parameter(Mandatory)]
        [string] $CollectionProfile,

        [string[]] $SkippedCollector = @()
    )

    $context = [ordered] @{
        Id = 7614
        Activity = 'Identity Atlas tenant collection'
        Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        Step = 0
        StepCount = $StepCount
        CompletedStepCount = 0
        CollectorName = ''
        CollectorDisplayName = 'Preparing collection'
        CollectorRequestStart = 0
        CollectorRetryStart = 0
        CurrentItem = 0
        TotalItems = 0
        ItemStatus = ''
        RequestCount = 0
        RetryCount = 0
        NodeCount = 0
        EdgeCount = 0
        EvidenceCount = 0
        SkippedCollectors = @($SkippedCollector)
    }
    $script:IdentityAtlasProgressContext = $context

    $skipText = if ($context.SkippedCollectors.Count -gt 0) {
        " Skipping: $($context.SkippedCollectors -join ', ')."
    }
    else {
        ''
    }
    Write-Information (
        "Identity Atlas collection started. Profile: $CollectionProfile.$skipText " +
        'Press Ctrl+C to cancel safely.'
    ) -InformationAction Continue

    return $context
}

function Get-AtlasProgressStatus {
    [CmdletBinding()]
    param()

    $context = $script:IdentityAtlasProgressContext
    if (-not $context) {
        return ''
    }

    $elapsed = Get-AtlasElapsedText -Stopwatch $context.Stopwatch
    $itemText = if ($context.TotalItems -gt 0) {
        " | Items $($context.CurrentItem)/$($context.TotalItems)"
    }
    else {
        ''
    }
    $detailText = if ($context.ItemStatus) { " | $($context.ItemStatus)" } else { '' }

    return (
        "$elapsed | Requests $($context.RequestCount) | Objects $($context.NodeCount)" +
        " | Relationships $($context.EdgeCount) | Evidence $($context.EvidenceCount)$itemText$detailText"
    )
}

function Write-AtlasProgressView {
    [CmdletBinding()]
    param()

    $context = $script:IdentityAtlasProgressContext
    if (-not $context) {
        return
    }

    $stepFraction = if ($context.TotalItems -gt 0) {
        [math]::Min(1, $context.CurrentItem / $context.TotalItems)
    }
    else {
        0
    }
    $completedStepCount = [math]::Max(0, $context.Step - 1)
    $percent = [math]::Min(
        99,
        [math]::Floor((($completedStepCount + $stepFraction) / $context.StepCount) * 100)
    )

    Write-Progress `
        -Id $context.Id `
        -Activity $context.Activity `
        -Status "[$($context.Step)/$($context.StepCount)] $($context.CollectorDisplayName) | $(Get-AtlasProgressStatus)" `
        -PercentComplete $percent
}

function Start-AtlasProgressStep {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Updates only in-memory progress state and writes a local progress record.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $DisplayName,

        [Parameter(Mandatory)]
        [ValidateRange(1, 30)]
        [int] $Step
    )

    $context = $script:IdentityAtlasProgressContext
    if (-not $context) {
        return
    }

    $context.Step = $Step
    $context.CollectorName = $Name
    $context.CollectorDisplayName = $DisplayName
    $context.CollectorRequestStart = $context.RequestCount
    $context.CollectorRetryStart = $context.RetryCount
    $context.CurrentItem = 0
    $context.TotalItems = 0
    $context.ItemStatus = 'Starting'
    Write-AtlasProgressView
    Write-Information (
        "[$Step/$($context.StepCount)] $DisplayName started | $(Get-AtlasProgressStatus)"
    ) -InformationAction Continue
}

function Update-AtlasProgressRequest {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Updates only in-memory progress counters.'
    )]
    [CmdletBinding()]
    param(
        [ValidateRange(0, 1000)]
        [int] $RequestIncrement = 0,

        [ValidateRange(0, 1000)]
        [int] $RetryIncrement = 0,

        [string] $Status
    )

    $context = $script:IdentityAtlasProgressContext
    if (-not $context) {
        return
    }

    $context.RequestCount += $RequestIncrement
    $context.RetryCount += $RetryIncrement
    if ($Status) {
        $context.ItemStatus = $Status
    }
    Write-AtlasProgressView
}

function Update-AtlasProgressItem {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Updates only in-memory progress counters.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $CurrentItem,

        [Parameter(Mandatory)]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $TotalItems,

        [string] $Status
    )

    $context = $script:IdentityAtlasProgressContext
    if (-not $context) {
        return
    }

    $context.CurrentItem = $CurrentItem
    $context.TotalItems = $TotalItems
    if ($Status) {
        $context.ItemStatus = $Status
    }
    Write-AtlasProgressView
}

function Complete-AtlasProgressStep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AtlasCollectionResult] $Result
    )

    $context = $script:IdentityAtlasProgressContext
    if (-not $context) {
        return
    }

    $context.NodeCount += $Result.Nodes.Count
    $context.EdgeCount += $Result.Edges.Count
    $context.EvidenceCount += $Result.Evidence.Count
    $context.CompletedStepCount = [math]::Max($context.CompletedStepCount, $context.Step)

    $reportedRequestCount = if ($Result.Metrics.ContainsKey('requestCount')) {
        [int] $Result.Metrics.requestCount
    }
    else {
        0
    }
    $observedRequestCount = $context.RequestCount - $context.CollectorRequestStart
    if ($reportedRequestCount -gt $observedRequestCount) {
        $context.RequestCount += $reportedRequestCount - $observedRequestCount
    }

    $reportedRetryCount = if ($Result.Metrics.ContainsKey('retryCount')) {
        [int] $Result.Metrics.retryCount
    }
    else {
        0
    }
    $observedRetryCount = $context.RetryCount - $context.CollectorRetryStart
    if ($reportedRetryCount -gt $observedRetryCount) {
        $context.RetryCount += $reportedRetryCount - $observedRetryCount
    }

    $context.CurrentItem = $context.TotalItems
    $context.ItemStatus = if ($Result.Status -eq 'complete') { 'Complete' } else { 'Partial coverage' }
    Write-AtlasProgressView
    Write-Information (
        "[$($context.Step)/$($context.StepCount)] $($context.CollectorDisplayName) $($context.ItemStatus.ToLowerInvariant())" +
        " | +$($Result.Nodes.Count) objects | +$($Result.Edges.Count) relationships" +
        " | +$($Result.Evidence.Count) evidence | $(Get-AtlasProgressStatus)"
    ) -InformationAction Continue
}

function Complete-AtlasProgress {
    [CmdletBinding()]
    param(
        [ValidateSet('Complete', 'Cancelled', 'Failed')]
        [string] $Status = 'Complete',

        [string] $OutputPath
    )

    $context = $script:IdentityAtlasProgressContext
    if (-not $context) {
        return $null
    }

    $context.Stopwatch.Stop()
    Write-Progress -Id $context.Id -Activity $context.Activity -Completed
    $elapsed = Get-AtlasElapsedText -Stopwatch $context.Stopwatch
    $summary = [pscustomobject] @{
        Status = $Status
        Duration = $context.Stopwatch.Elapsed
        DurationText = $elapsed
        RequestCount = $context.RequestCount
        RetryCount = $context.RetryCount
        NodeCount = $context.NodeCount
        EdgeCount = $context.EdgeCount
        EvidenceCount = $context.EvidenceCount
        CompletedStepCount = if ($Status -eq 'Complete') { $context.StepCount } else { $context.CompletedStepCount }
        StepCount = $context.StepCount
        CurrentCollector = $context.CollectorDisplayName
        SkippedCollectors = @($context.SkippedCollectors)
        OutputPath = $OutputPath
    }

    $message = switch ($Status) {
        'Complete' { 'Identity Atlas collection completed' }
        'Cancelled' { 'Identity Atlas collection cancelled safely' }
        default { 'Identity Atlas collection stopped after an unexpected error' }
    }
    Write-Information (
        "$message after $elapsed | Requests $($context.RequestCount) | Retries $($context.RetryCount)" +
        " | Objects $($context.NodeCount) | Relationships $($context.EdgeCount) | Evidence $($context.EvidenceCount)"
    ) -InformationAction Continue

    $script:IdentityAtlasProgressContext = $null
    return $summary
}
