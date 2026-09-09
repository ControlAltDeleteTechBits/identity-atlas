function Initialize-AtlasCheckpoint {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates only the explicitly requested local checkpoint.')]
    [CmdletBinding()]
    param([string] $Path, [hashtable] $Identity, [switch] $Resume)
    $root = [IO.Path]::GetFullPath($Path)
    $project = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    if ($root.TrimEnd('\', '/') -eq [IO.Path]::GetPathRoot($root).TrimEnd('\', '/')) { throw 'A checkpoint cannot use a filesystem root.' }
    if ($root.StartsWith($project, [StringComparison]::OrdinalIgnoreCase) -and -not $root.StartsWith((Join-Path $project 'Output') + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Store checkpoints outside the source tree or inside its ignored Output directory.'
    }
    $marker = Join-Path $root 'checkpoint.json'
    $canonicalIdentity = [ordered]@{}
    foreach ($key in ($Identity.Keys | Sort-Object)) { $canonicalIdentity[$key] = $Identity[$key] }
    $fingerprint = Get-AtlasStableId -InputString ($canonicalIdentity | ConvertTo-Json -Depth 8 -Compress)
    if ($Resume) {
        if (-not (Test-Path -LiteralPath $marker -PathType Leaf)) { throw 'No checkpoint was found. Start a run with -Checkpoint first.' }
        $previous = Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
        if ($previous.fingerprint -ne $fingerprint) { throw 'Checkpoint tenant, account, permissions, settings or module version differ. Start a new collection.' }
        if ([datetime]::UtcNow - [datetime]$previous.createdAtUtc -gt [timespan]::FromHours(24)) { throw 'Checkpoint is older than 24 hours. Start a new collection in a new output folder.' }
    }
    else {
        if (Test-Path -LiteralPath $root) { throw 'Checkpoint folder already exists. Use -Resume or choose a new output folder.' }
        $null = New-Item -ItemType Directory -Path $root
        Write-AtlasTextFile -Path $marker -Content (@{ fingerprint = $fingerprint; createdAtUtc = [datetime]::UtcNow.ToString('o'); format = 'IdentityAtlasCheckpoint1' } | ConvertTo-Json)
    }
    $script:AtlasCheckpoint = @{ Root = $root; TenantId = $Identity.tenant; Resume = [bool]$Resume; Refreshing = $false; Reused = [System.Collections.Generic.List[string]]::new() }
    Write-Information 'Checkpointing enabled. Checkpoints contain sensitive tenant evidence, not credentials. Resume is limited to the same context and 24 hours.' -InformationAction Continue
}

function Get-AtlasCheckpointResult {
    [CmdletBinding()]
    param([ValidatePattern('^[A-Za-z][A-Za-z0-9]{0,63}$')] [string] $Name)
    $state = Get-Variable AtlasCheckpoint -Scope Script -ValueOnly -ErrorAction SilentlyContinue
    if (-not $state -or -not $state.Resume -or $state.Refreshing) { return $null }
    $path = Join-Path $state.Root "$Name.json"
    if (-not (Test-Path -LiteralPath $path)) { $state.Refreshing = $true; return $null }
    $data = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable -Depth 40
    if ($data.Status -ne 'complete') { $state.Refreshing = $true; return $null }
    $result = [AtlasCollectionResult]::new()
    foreach ($item in $data.Nodes) { if ($item.TenantId -ne $state.TenantId) { throw 'Checkpoint contains another tenant.' }; $result.Nodes.Add([AtlasNode]$item) }
    foreach ($item in $data.Edges) { if ($item.TenantId -ne $state.TenantId) { throw 'Checkpoint contains another tenant.' }; $result.Edges.Add([AtlasEdge]$item) }
    foreach ($item in $data.Evidence) { if ($item.TenantId -ne $state.TenantId) { throw 'Checkpoint contains another tenant.' }; $result.Evidence.Add([AtlasEvidence]$item) }
    foreach ($warning in $data.Warnings) { $result.Warnings.Add($warning) }
    $result.Metrics = $data.Metrics
    $result.Metrics.checkpointReused = $true
    $result.Metrics.requestCount = 0
    $result.Metrics.retryCount = 0
    $state.Reused.Add($Name)
    Write-Information "Reusing completed checkpoint: $Name. Original evidence timestamps retained." -InformationAction Continue
    return $result
}

function Save-AtlasCheckpointResult {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Saves projected collector data to the explicitly requested checkpoint.')]
    [CmdletBinding()]
    param([ValidatePattern('^[A-Za-z][A-Za-z0-9]{0,63}$')] [string] $Name, [AtlasCollectionResult] $Result)
    $state = Get-Variable AtlasCheckpoint -Scope Script -ValueOnly -ErrorAction SilentlyContinue
    if ($state) { Write-AtlasTextFile -Path (Join-Path $state.Root "$Name.json") -Content ($Result | ConvertTo-Json -Depth 40) }
}
