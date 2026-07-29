function Merge-AtlasCollectionResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AtlasCollectionResult[]] $Result
    )

    $merged = [AtlasCollectionResult]::new()
    $nodes = [ordered]@{}
    $edges = [ordered]@{}
    $evidence = [ordered]@{}

    foreach ($item in $Result) {
        foreach ($node in $item.Nodes) {
            if ($null -eq $node -or [string]::IsNullOrWhiteSpace($node.Key)) {
                $merged.Status = 'partial'
                $merged.Warnings.Add('A collector returned a node without a graph key. The invalid node was omitted.')
                continue
            }
            if (-not $nodes.Contains($node.Key) -or $nodes[$node.Key].Status -eq 'unresolved') {
                $nodes[$node.Key] = $node
            }
        }

        foreach ($edge in $item.Edges) {
            if ($null -eq $edge -or [string]::IsNullOrWhiteSpace($edge.Key)) {
                $merged.Status = 'partial'
                $merged.Warnings.Add('A collector returned a relationship without a graph key. The invalid relationship was omitted.')
                continue
            }
            $edges[$edge.Key] = $edge
        }

        foreach ($record in $item.Evidence) {
            if ($null -eq $record -or [string]::IsNullOrWhiteSpace($record.Key)) {
                $merged.Status = 'partial'
                $merged.Warnings.Add('A collector returned evidence without a graph key. The invalid evidence record was omitted.')
                continue
            }
            $evidence[$record.Key] = $record
        }

        foreach ($warning in $item.Warnings) {
            $merged.Warnings.Add($warning)
        }
    }

    foreach ($node in $nodes.Values) {
        $merged.Nodes.Add($node)
    }
    foreach ($edge in $edges.Values) {
        $merged.Edges.Add($edge)
    }
    foreach ($record in $evidence.Values) {
        $merged.Evidence.Add($record)
    }

    if ($Result.Status -contains 'partial') {
        $merged.Status = 'partial'
    }

    $merged.Metrics = @{
        nodeCount = $merged.Nodes.Count
        edgeCount = $merged.Edges.Count
        evidenceCount = $merged.Evidence.Count
    }
    return $merged
}
