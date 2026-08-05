function Compare-IdentityAtlas {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $ReferenceReportPath,

        [Parameter(Mandatory)]
        [string] $DifferenceReportPath,

        [string] $OutputPath
    )

    function Read-AtlasReportJson {
        param([string] $Path)

        $candidate = if ((Get-Item -LiteralPath $Path).PSIsContainer) {
            Join-Path $Path 'data/report.json'
        }
        else {
            $Path
        }

        return Get-Content -Raw -LiteralPath $candidate | ConvertFrom-Json -Depth 30
    }

    $reference = Read-AtlasReportJson -Path $ReferenceReportPath
    $difference = Read-AtlasReportJson -Path $DifferenceReportPath

    $referenceNodes = @{}
    $differenceNodes = @{}
    $referenceEdges = @{}
    $differenceEdges = @{}

    foreach ($node in $reference.nodes) { $referenceNodes[$node.Key] = $node }
    foreach ($node in $difference.nodes) { $differenceNodes[$node.Key] = $node }
    foreach ($edge in $reference.edges) { $referenceEdges[$edge.Key] = $edge }
    foreach ($edge in $difference.edges) { $differenceEdges[$edge.Key] = $edge }

    function Convert-AtlasNodeSummary {
        param([object] $Node)

        [pscustomobject] @{
            key = $Node.Key
            id = $Node.Id
            kind = $Node.Kind
            displayName = $Node.DisplayName
            status = $Node.Status
        }
    }

    function Convert-AtlasEdgeSummary {
        param([object] $Edge, [hashtable] $NodeLookup)

        $from = $NodeLookup[$Edge.From]
        $to = $NodeLookup[$Edge.To]
        [pscustomobject] @{
            key = $Edge.Key
            relationship = $Edge.Relationship
            from = if ($from) { $from.DisplayName } else { $Edge.From }
            fromKind = if ($from) { $from.Kind } else { 'unresolved' }
            to = if ($to) { $to.DisplayName } else { $Edge.To }
            toKind = if ($to) { $to.Kind } else { 'unresolved' }
            state = $Edge.State
        }
    }

    function ConvertTo-AtlasStableNode {
        param([object] $Node)

        [pscustomobject] @{
            id = $Node.Id
            kind = $Node.Kind
            displayName = $Node.DisplayName
            status = $Node.Status
            tags = @($Node.Tags)
            properties = $Node.Properties
            source = $Node.Source
        }
    }

    function ConvertTo-AtlasStableEdge {
        param([object] $Edge)

        [pscustomobject] @{
            from = $Edge.From
            to = $Edge.To
            relationship = $Edge.Relationship
            state = $Edge.State
            source = $Edge.Source
        }
    }

    function ConvertTo-AtlasStableJson {
        param([object] $InputObject)

        return ($InputObject | ConvertTo-Json -Depth 30 -Compress)
    }

    $addedNodes = @($differenceNodes.Keys | Where-Object { -not $referenceNodes.ContainsKey($_) } | ForEach-Object {
        Convert-AtlasNodeSummary -Node $differenceNodes[$_]
    })
    $removedNodes = @($referenceNodes.Keys | Where-Object { -not $differenceNodes.ContainsKey($_) } | ForEach-Object {
        Convert-AtlasNodeSummary -Node $referenceNodes[$_]
    })
    $addedEdges = @($differenceEdges.Keys | Where-Object { -not $referenceEdges.ContainsKey($_) } | ForEach-Object {
        Convert-AtlasEdgeSummary -Edge $differenceEdges[$_] -NodeLookup $differenceNodes
    })
    $removedEdges = @($referenceEdges.Keys | Where-Object { -not $differenceEdges.ContainsKey($_) } | ForEach-Object {
        Convert-AtlasEdgeSummary -Edge $referenceEdges[$_] -NodeLookup $referenceNodes
    })
    $changedNodes = @($differenceNodes.Keys | Where-Object {
        $referenceNodes.ContainsKey($_) -and
        (ConvertTo-AtlasStableJson -InputObject (ConvertTo-AtlasStableNode -Node $referenceNodes[$_])) -ne
            (ConvertTo-AtlasStableJson -InputObject (ConvertTo-AtlasStableNode -Node $differenceNodes[$_]))
    } | ForEach-Object {
        [pscustomobject] @{
            key = $_
            before = Convert-AtlasNodeSummary -Node $referenceNodes[$_]
            after = Convert-AtlasNodeSummary -Node $differenceNodes[$_]
            beforeProperties = $referenceNodes[$_].Properties
            afterProperties = $differenceNodes[$_].Properties
        }
    })
    $changedEdges = @($differenceEdges.Keys | Where-Object {
        $referenceEdges.ContainsKey($_) -and
        (ConvertTo-AtlasStableJson -InputObject (ConvertTo-AtlasStableEdge -Edge $referenceEdges[$_])) -ne
            (ConvertTo-AtlasStableJson -InputObject (ConvertTo-AtlasStableEdge -Edge $differenceEdges[$_]))
    } | ForEach-Object {
        [pscustomobject] @{
            key = $_
            before = Convert-AtlasEdgeSummary -Edge $referenceEdges[$_] -NodeLookup $referenceNodes
            after = Convert-AtlasEdgeSummary -Edge $differenceEdges[$_] -NodeLookup $differenceNodes
        }
    })

    $comparison = [pscustomobject] @{
        generatedAtUtc = ([datetime]::UtcNow.ToString('o'))
        reference = [pscustomobject] @{
            tenant = $reference.manifest.tenant.displayName
            generatedAtUtc = $reference.manifest.generatedAtUtc
            counts = $reference.manifest.counts
        }
        difference = [pscustomobject] @{
            tenant = $difference.manifest.tenant.displayName
            generatedAtUtc = $difference.manifest.generatedAtUtc
            counts = $difference.manifest.counts
        }
        summary = [pscustomobject] @{
            addedNodes = $addedNodes.Count
            removedNodes = $removedNodes.Count
            changedNodes = $changedNodes.Count
            addedEdges = $addedEdges.Count
            removedEdges = $removedEdges.Count
            changedEdges = $changedEdges.Count
        }
        addedNodes = $addedNodes
        removedNodes = $removedNodes
        changedNodes = $changedNodes
        addedEdges = $addedEdges
        removedEdges = $removedEdges
        changedEdges = $changedEdges
    }

    if ($OutputPath) {
        $resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
        $null = New-Item -ItemType Directory -Path $resolvedOutputPath -Force
        $jsonPath = Join-Path $resolvedOutputPath 'comparison.json'
        $markdownPath = Join-Path $resolvedOutputPath 'comparison.md'
        $htmlPath = Join-Path $resolvedOutputPath 'comparison.html'
        Write-AtlasTextFile -Path $jsonPath -Content ($comparison | ConvertTo-Json -Depth 30)

        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add('# Identity Atlas comparison')
        $lines.Add('')
        $lines.Add("Generated at UTC: $($comparison.generatedAtUtc)")
        $lines.Add('')
        $lines.Add('## Summary')
        $lines.Add('')
        $lines.Add("Added objects: $($comparison.summary.addedNodes)")
        $lines.Add("Removed objects: $($comparison.summary.removedNodes)")
        $lines.Add("Changed objects: $($comparison.summary.changedNodes)")
        $lines.Add("Added relationships: $($comparison.summary.addedEdges)")
        $lines.Add("Removed relationships: $($comparison.summary.removedEdges)")
        $lines.Add("Changed relationships: $($comparison.summary.changedEdges)")
        $lines.Add('')
        foreach ($section in @(
            @{ Title = 'Added objects'; Items = $addedNodes; Format = { param($item) "- $($item.displayName) [$($item.kind)]" } }
            @{ Title = 'Removed objects'; Items = $removedNodes; Format = { param($item) "- $($item.displayName) [$($item.kind)]" } }
            @{ Title = 'Changed objects'; Items = $changedNodes; Format = { param($item) "- $($item.after.displayName) [$($item.after.kind)]" } }
            @{ Title = 'Added relationships'; Items = $addedEdges; Format = { param($item) "- $($item.from) $($item.relationship) $($item.to)" } }
            @{ Title = 'Removed relationships'; Items = $removedEdges; Format = { param($item) "- $($item.from) $($item.relationship) $($item.to)" } }
            @{ Title = 'Changed relationships'; Items = $changedEdges; Format = { param($item) "- $($item.after.from) $($item.after.relationship) $($item.after.to)" } }
        )) {
            $lines.Add("## $($section.Title)")
            $lines.Add('')
            if ($section.Items.Count -eq 0) {
                $lines.Add('None.')
            }
            else {
                foreach ($item in $section.Items | Select-Object -First 50) {
                    $lines.Add((& $section.Format $item))
                }
            }
            $lines.Add('')
        }
        Write-AtlasTextFile -Path $markdownPath -Content ($lines -join "`n")

        $comparisonJson = ($comparison | ConvertTo-Json -Depth 30 -Compress)
        $comparisonDataPath = Join-Path $resolvedOutputPath 'comparison-data.js'
        $comparisonAppPath = Join-Path $resolvedOutputPath 'comparison-app.js'
        Write-AtlasTextFile `
            -Path $comparisonDataPath `
            -Content "window.IdentityAtlasComparisonData = $comparisonJson;"

        $comparisonApplication = @'
(function initialiseIdentityAtlasComparison() {
  'use strict';

  const comparison = window.IdentityAtlasComparisonData;
  if (!comparison) {
    throw new Error('Identity Atlas comparison data is unavailable.');
  }

  const make = (tag, className, text) => {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text !== undefined) element.textContent = text;
    return element;
  };
  document.getElementById('comparison-range').textContent =
    comparison.reference.tenant + ' compared with ' + comparison.difference.tenant;
  const cards = document.getElementById('summary-cards');
  for (const [label, value, className] of [
    ['Added objects', comparison.summary.addedNodes, 'added'],
    ['Removed objects', comparison.summary.removedNodes, 'removed'],
    ['Changed objects', comparison.summary.changedNodes, 'changed'],
    ['Added relationships', comparison.summary.addedEdges, 'added'],
    ['Removed relationships', comparison.summary.removedEdges, 'removed'],
    ['Changed relationships', comparison.summary.changedEdges, 'changed']
  ]) {
    const card = make('div', 'card');
    card.append(make('span', 'label', label), make('span', 'value ' + className, String(value)));
    cards.append(card);
  }
  const renderEmpty = (container) => container.append(make('div', 'item meta', 'None.'));
  const renderNodes = (id, items, mode) => {
    const container = document.getElementById(id);
    if (!items.length) { renderEmpty(container); return; }
    for (const item of items.slice(0, 100)) {
      const node = item.displayName ? item : item.after;
      const row = make('div', 'item');
      row.append(make('span', mode, node.displayName), make('span', 'meta', node.kind + ' | ' + node.id));
      if (item.beforeProperties || item.afterProperties) {
        row.append(make('pre', null, JSON.stringify({ before: item.beforeProperties, after: item.afterProperties }, null, 2)));
      }
      container.append(row);
    }
  };
  const renderEdges = (id, items, mode) => {
    const container = document.getElementById(id);
    if (!items.length) { renderEmpty(container); return; }
    for (const item of items.slice(0, 100)) {
      const edge = item.relationship ? item : item.after;
      const row = make('div', 'item');
      row.append(make('span', mode, edge.from + ' ' + edge.relationship + ' ' + edge.to), make('span', 'meta', edge.fromKind + ' to ' + edge.toKind));
      if (item.before || item.after) {
        row.append(make('pre', null, JSON.stringify({ before: item.before.state, after: item.after.state }, null, 2)));
      }
      container.append(row);
    }
  };
  renderNodes('added-nodes', comparison.addedNodes, 'added');
  renderNodes('removed-nodes', comparison.removedNodes, 'removed');
  renderNodes('changed-nodes', comparison.changedNodes, 'changed');
  renderEdges('added-edges', comparison.addedEdges, 'added');
  renderEdges('removed-edges', comparison.removedEdges, 'removed');
  renderEdges('changed-edges', comparison.changedEdges, 'changed');
}());
'@
        Write-AtlasTextFile -Path $comparisonAppPath -Content $comparisonApplication

        $html = @"
<!doctype html>
<html lang="en-GB">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'self'; style-src 'unsafe-inline'; img-src 'self' data:; connect-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'">
  <meta name="referrer" content="no-referrer">
  <title>Identity Atlas comparison</title>
  <style>
    :root { color-scheme: light; --ink: #102033; --muted: #5d6c7d; --line: #dde5ee; --panel: #ffffff; --canvas: #f5f7fa; --brand: #102033; --accent: #49a4ad; --added: #0f7b48; --removed: #a23d3d; --changed: #8a6517; }
    * { box-sizing: border-box; }
    body { margin: 0; background: var(--canvas); color: var(--ink); font-family: Arial, "Helvetica Neue", sans-serif; line-height: 1.45; }
    header { padding: 32px; background: var(--brand); color: #fff; }
    header p { margin: 6px 0 0; color: #c7d3df; }
    main { display: grid; gap: 18px; padding: 24px; }
    .cards { display: grid; gap: 14px; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); }
    .card, section { background: var(--panel); border: 1px solid var(--line); border-radius: 14px; box-shadow: 0 8px 24px rgb(15 29 45 / 7%); }
    .card { padding: 18px; }
    .label { display: block; color: var(--muted); font-size: 12px; text-transform: uppercase; letter-spacing: 0.08em; }
    .value { display: block; margin-top: 8px; font-size: 28px; font-weight: 700; }
    section { overflow: hidden; }
    section h2 { margin: 0; padding: 18px 20px; border-bottom: 1px solid var(--line); font-size: 18px; }
    .item { display: grid; gap: 4px; padding: 14px 20px; border-top: 1px solid #edf1f5; }
    .item:first-of-type { border-top: 0; }
    .meta { color: var(--muted); font-size: 13px; }
    .added { color: var(--added); }
    .removed { color: var(--removed); }
    .changed { color: var(--changed); }
    pre { margin: 8px 0 0; padding: 12px; overflow: auto; background: #f7f9fb; border: 1px solid var(--line); border-radius: 10px; font-size: 12px; }
    @media (max-width: 720px) { header, main { padding: 18px; } }
  </style>
</head>
<body>
  <header>
    <span class="label">Identity Atlas</span>
    <h1>Report comparison</h1>
    <p id="comparison-range"></p>
  </header>
  <main>
    <div class="cards" id="summary-cards"></div>
    <section><h2 class="added">Added objects</h2><div id="added-nodes"></div></section>
    <section><h2 class="removed">Removed objects</h2><div id="removed-nodes"></div></section>
    <section><h2 class="changed">Changed objects</h2><div id="changed-nodes"></div></section>
    <section><h2 class="added">Added relationships</h2><div id="added-edges"></div></section>
    <section><h2 class="removed">Removed relationships</h2><div id="removed-edges"></div></section>
    <section><h2 class="changed">Changed relationships</h2><div id="changed-edges"></div></section>
  </main>
  <script defer src="comparison-data.js"></script>
  <script defer src="comparison-app.js"></script>
</body>
</html>
"@
        Write-AtlasTextFile -Path $htmlPath -Content $html
    }

    return $comparison
}
