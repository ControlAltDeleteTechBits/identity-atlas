function Get-AtlasCompletionSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object] $Report,
        [Parameter(Mandatory)] [string] $ReportPath,
        [string[]] $SkippedCollector = @()
    )
    $collectors = @($Report.manifest.coverage.collectors)
    $complete = @($collectors | Where-Object status -eq 'complete' | ForEach-Object { $_.name })
    $incomplete = @($collectors | Where-Object status -ne 'complete' | ForEach-Object { $_.name })
    $nextActions = [System.Collections.Generic.List[string]]::new()
    if ($Report.manifest.coverage.status -ne 'complete') {
        $nextActions.Add('Open Overview and review coverage diagnostics before interpreting missing relationships. Partial coverage does not prove that access or authentication methods are absent.')
    }
    if ($incomplete -contains 'permissionPreflight') {
        $nextActions.Add('Run Test-IdentityAtlasConnection with the same CollectionProfile and IncludeConsent options. Check missing read scopes; scope consent alone does not prove endpoint authorisation.')
    }
    if ($incomplete -contains 'devicesAndAuthentication') {
        $nextActions.Add('Check each affected user''s authentication collection status. Access denied remains unknown; verify endpoint authorisation before changing permissions or tenant controls.')
    }
    if ($SkippedCollector.Count -gt 0) {
        $nextActions.Add('Skipped data remains unavailable. Collect it in a new report without the skip options when required.')
    }
    $nextActions.Add('Keep the report and any checkpoints private: they contain tenant evidence. Review the evidence and current tenant state before making changes.')
    [pscustomobject] @{
        CompleteCollectors = $complete
        IncompleteCollectors = $incomplete
        WarningCount = @($Report.manifest.coverage.warnings).Count
        SkippedCollectors = @($SkippedCollector)
        NextActions = @($nextActions)
        ReopenCommand = "Open-IdentityAtlasReport -Path '$($ReportPath.Replace("'", "''"))'"
    }
}

function Write-AtlasInterruptedCollectionGuidance {
    [CmdletBinding()]
    param()
    Write-Information 'No completed report is being returned by this run. Counts above describe work processed, not a saved report.' -InformationAction Continue
    $checkpoint = Get-Variable AtlasCheckpoint -Scope Script -ValueOnly -ErrorAction SilentlyContinue
    if ($checkpoint) {
        Write-Information "Checkpoint folder: $($checkpoint.Root). Re-run the original Invoke-IdentityAtlas command with -Resume and the same collection options, account and module within 24 hours. Completed collectors can be reused; an interrupted collector starts again. Checkpoints contain sensitive tenant evidence." -InformationAction Continue
    }
    else {
        Write-Information 'No checkpoint is active. Start a new collection; use -Checkpoint if you want completed collectors retained for resume.' -InformationAction Continue
    }
}
