function Add-AtlasApplicationAdminDetail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [AtlasCollectionResult] $Result,
        [ValidateRange(1, 20)] [int] $BatchSize = 10
    )
    $targets = @($Result.Nodes | Where-Object Kind -eq application)
    $metrics = @{ requestCount = 0; retryCount = 0; logicalRequestCount = 0 }
    if ($targets.Count -eq 0) { return $metrics }
    $byId = @{}
    $requests = @(for ($index = 0; $index -lt $targets.Count; $index++) {
        $requestId = "federation-$index"
        $byId[$requestId] = $targets[$index]
        [pscustomobject] @{
            Id = $requestId
            Uri = "/v1.0/applications/$($targets[$index].Id)/federatedIdentityCredentials?`$select=id,name,issuer,subject,audiences,description"
        }
    })
    try {
        $batch = Invoke-AtlasGraphBatchGet -Request $requests -BatchSize $BatchSize -ProgressStatus 'Application federation metadata'
        $metrics = $batch.Metrics
        foreach ($response in $batch.Responses) {
            $node = $byId[$response.Id]
            if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
                $node.Properties.federationCollectionStatus = 'partial'
                $Result.Status = 'partial'
                $Result.Warnings.Add("Federated credential metadata could not be collected for application '$($node.DisplayName)'.")
                continue
            }
            $node.Properties.federatedIdentityCredentials = @($response.Items | ForEach-Object {
                $metadata = @{}
                foreach ($field in @('id', 'name', 'issuer', 'subject', 'audiences', 'description')) {
                    $metadata[$field] = Get-AtlasResponseProperty -InputObject $_ -Name $field
                }
                $metadata
            })
            $node.Properties.federationCollectionStatus = 'complete'
        }
    }
    catch {
        $Result.Status = 'partial'
        $Result.Warnings.Add("Application federation metadata collection failed: $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
        foreach ($node in $targets) { $node.Properties.federationCollectionStatus = 'partial' }
    }
    return $metrics
}
