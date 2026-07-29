function Export-IdentityAtlas {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [psobject] $InputObject,

        [Parameter(Mandatory)]
        [string] $OutputPath,

        [ValidateSet('HtmlReport', 'Json', 'Csv', 'Markdown')]
        [string] $Format = 'HtmlReport'
    )

    process {
        if ($Format -eq 'HtmlReport') {
            Write-AtlasReport -Report $InputObject -OutputPath $OutputPath
            return
        }

        $resolvedOutputPath = [System.IO.Path]::GetFullPath($OutputPath)
        $null = New-Item -ItemType Directory -Path $resolvedOutputPath -Force

        if ($Format -eq 'Json') {
            Write-AtlasTextFile -Path (Join-Path $resolvedOutputPath 'report.json') -Content ($InputObject | ConvertTo-Json -Depth 30)
            return Get-Item -LiteralPath (Join-Path $resolvedOutputPath 'report.json')
        }

        if ($Format -eq 'Csv') {
            $InputObject.nodes | Select-Object Key, Id, Kind, DisplayName, Status |
                Export-Csv -LiteralPath (Join-Path $resolvedOutputPath 'nodes.csv') -NoTypeInformation
            $InputObject.edges | Select-Object Key, From, To, Relationship |
                Export-Csv -LiteralPath (Join-Path $resolvedOutputPath 'edges.csv') -NoTypeInformation
            $InputObject.evidence | Select-Object Key, Collector, Endpoint, SourceObjectId, Completeness |
                Export-Csv -LiteralPath (Join-Path $resolvedOutputPath 'evidence.csv') -NoTypeInformation
            return Get-Item -LiteralPath $resolvedOutputPath
        }

        if ($Format -eq 'Markdown') {
            $lines = [System.Collections.Generic.List[string]]::new()
            $lines.Add('# Identity Atlas report summary')
            $lines.Add('')
            $lines.Add("Tenant: $($InputObject.manifest.tenant.displayName)")
            $lines.Add("Generated at UTC: $($InputObject.manifest.generatedAtUtc)")
            $lines.Add("Coverage: $($InputObject.manifest.coverage.status)")
            $lines.Add('')
            $lines.Add('## Counts')
            $lines.Add('')
            $lines.Add("Objects: $($InputObject.manifest.counts.nodes)")
            $lines.Add("Relationships: $($InputObject.manifest.counts.edges)")
            $lines.Add("Evidence records: $($InputObject.manifest.counts.evidence)")
            $lines.Add('')
            $lines.Add('## Object types')
            $lines.Add('')
            foreach ($group in $InputObject.nodes | Group-Object Kind | Sort-Object Name) {
                $lines.Add("- $($group.Name): $($group.Count)")
            }
            $lines.Add('')
            $lines.Add('## Relationship types')
            $lines.Add('')
            foreach ($group in $InputObject.edges | Group-Object Relationship | Sort-Object Name) {
                $lines.Add("- $($group.Name): $($group.Count)")
            }
            if ($InputObject.manifest.coverage.warnings.Count) {
                $lines.Add('')
                $lines.Add('## Coverage warnings')
                $lines.Add('')
                foreach ($warning in $InputObject.manifest.coverage.warnings) {
                    $lines.Add("- $warning")
                }
            }
            Write-AtlasTextFile -Path (Join-Path $resolvedOutputPath 'report-summary.md') -Content ($lines -join "`n")
            return Get-Item -LiteralPath (Join-Path $resolvedOutputPath 'report-summary.md')
        }
    }
}
