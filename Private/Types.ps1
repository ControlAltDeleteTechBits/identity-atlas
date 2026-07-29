class AtlasObject {
    [string] $Key
    [string] $Id
    [string] $Kind
    [string] $TenantId
    [datetime] $CollectedAtUtc
    [hashtable] $Source = @{}
    [hashtable] $Properties = @{}
}

class AtlasNode : AtlasObject {
    [string] $DisplayName
    [string] $Status = 'complete'
    [string[]] $Tags = @()
}

class AtlasEdge : AtlasObject {
    [string] $From
    [string] $To
    [string] $Relationship
    [hashtable] $State = @{}
    [string[]] $EvidenceIds = @()
}

class AtlasEvidence : AtlasObject {
    [string] $Collector
    [string] $Endpoint
    [string] $SourceObjectId
    [string] $Completeness = 'complete'
    [hashtable] $Fields = @{}
}

class AtlasCollectionResult {
    [System.Collections.Generic.List[AtlasNode]] $Nodes
    [System.Collections.Generic.List[AtlasEdge]] $Edges
    [System.Collections.Generic.List[AtlasEvidence]] $Evidence
    [string] $Status = 'complete'
    [System.Collections.Generic.List[string]] $Warnings
    [hashtable] $Metrics = @{}

    AtlasCollectionResult() {
        $this.Nodes = [System.Collections.Generic.List[AtlasNode]]::new()
        $this.Edges = [System.Collections.Generic.List[AtlasEdge]]::new()
        $this.Evidence = [System.Collections.Generic.List[AtlasEvidence]]::new()
        $this.Warnings = [System.Collections.Generic.List[string]]::new()
    }
}
