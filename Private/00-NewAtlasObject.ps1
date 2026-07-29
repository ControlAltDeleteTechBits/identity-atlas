function Get-AtlasStableId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $InputString
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    $hex = [System.Convert]::ToHexString($hash).ToLowerInvariant()
    return $hex.Substring(0, 24)
}

function New-AtlasNode {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Creates an in-memory model object and does not change external state.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TenantId,

        [Parameter(Mandatory)]
        [string] $Id,

        [Parameter(Mandatory)]
        [string] $Kind,

        [Parameter(Mandatory)]
        [string] $DisplayName,

        [hashtable] $Properties = @{},

        [hashtable] $Source = @{},

        [ValidateSet('complete', 'partial', 'unresolved')]
        [string] $Status = 'complete',

        [string[]] $Tags = @()
    )

    $node = [AtlasNode]::new()
    $node.Key = "tenant:$TenantId`:graph:$Id"
    $node.Id = $Id
    $node.Kind = $Kind
    $node.TenantId = $TenantId
    $node.DisplayName = $DisplayName
    $node.Properties = $Properties
    $node.Source = $Source
    $node.Status = $Status
    $node.Tags = $Tags
    $node.CollectedAtUtc = [datetime]::UtcNow
    return $node
}

function New-AtlasEvidence {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Creates an in-memory evidence object and does not change external state.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TenantId,

        [Parameter(Mandatory)]
        [string] $Collector,

        [Parameter(Mandatory)]
        [string] $Endpoint,

        [Parameter(Mandatory)]
        [string] $SourceObjectId,

        [hashtable] $Fields = @{},

        [ValidateSet('complete', 'partial')]
        [string] $Completeness = 'complete'
    )

    $stableId = Get-AtlasStableId -InputString "$TenantId|$Collector|$Endpoint|$SourceObjectId|$($Fields | ConvertTo-Json -Compress -Depth 8)"
    $evidence = [AtlasEvidence]::new()
    $evidence.Key = "evidence:$stableId"
    $evidence.Id = $stableId
    $evidence.Kind = 'evidence'
    $evidence.TenantId = $TenantId
    $evidence.Collector = $Collector
    $evidence.Endpoint = $Endpoint
    $evidence.SourceObjectId = $SourceObjectId
    $evidence.Completeness = $Completeness
    $evidence.Fields = $Fields
    $evidence.Source = @{
        provider = 'microsoftGraph'
    }
    $evidence.CollectedAtUtc = [datetime]::UtcNow
    return $evidence
}

function New-AtlasEdge {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'Creates an in-memory relationship object and does not change external state.'
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TenantId,

        [Parameter(Mandatory)]
        [string] $From,

        [Parameter(Mandatory)]
        [string] $To,

        [Parameter(Mandatory)]
        [string] $Relationship,

        [hashtable] $State = @{},

        [string[]] $EvidenceIds = @(),

        [hashtable] $Source = @{}
    )

    $stableId = Get-AtlasStableId -InputString "$TenantId|$From|$Relationship|$To|$($State | ConvertTo-Json -Compress -Depth 8)"
    $edge = [AtlasEdge]::new()
    $edge.Key = "edge:$stableId"
    $edge.Id = $stableId
    $edge.Kind = 'relationship'
    $edge.TenantId = $TenantId
    $edge.From = $From
    $edge.To = $To
    $edge.Relationship = $Relationship
    $edge.State = $State
    $edge.EvidenceIds = $EvidenceIds
    $edge.Source = $Source
    $edge.CollectedAtUtc = [datetime]::UtcNow
    return $edge
}
