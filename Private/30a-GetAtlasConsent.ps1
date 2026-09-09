function Get-AtlasConsent {
    [CmdletBinding()]
    param([string] $TenantId, [AllowEmptyCollection()] [AtlasNode[]] $KnownNode)
    $result = [AtlasCollectionResult]::new()
    $lookup = @{}
    foreach ($node in $KnownNode) { $lookup[$node.Id] = $node }
    $endpoint = '/v1.0/oauth2PermissionGrants'
    $response = Invoke-AtlasGraphRequest -Uri $endpoint
    foreach ($grant in $response.Items) {
        if (-not $grant.id -or -not $grant.clientId -or -not $grant.resourceId -or $grant.consentType -notin @('Principal', 'AllPrincipals')) {
            $result.Status = 'partial'
            $result.Warnings.Add('A delegated consent record was incomplete or had an unsupported consent type.')
            continue
        }
        foreach ($referenceId in @($grant.clientId, $grant.resourceId, $grant.principalId) | Where-Object { $_ }) {
            if (-not $lookup.ContainsKey($referenceId)) {
                $kind = if ($referenceId -eq $grant.principalId) { 'user' } else { 'servicePrincipal' }
                $placeholder = New-AtlasNode -TenantId $TenantId -Id $referenceId -Kind $kind -DisplayName $referenceId -Status unresolved -Source @{ collector = 'delegatedConsent' }
                $result.Nodes.Add($placeholder)
                $lookup[$referenceId] = $placeholder
                $result.Status = 'partial'
                $result.Warnings.Add('A delegated consent reference could not be resolved from collected objects.')
            }
        }
        if ($grant.consentType -eq 'Principal' -and -not $grant.principalId) {
            $result.Status = 'partial'
            $result.Warnings.Add('A user-specific consent record has no principal identifier.')
            continue
        }
        $fields = @{ consentType = $grant.consentType; clientId = $grant.clientId; resourceId = $grant.resourceId; principalId = $grant.principalId; scope = $grant.scope }
        $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'delegatedConsent' -Endpoint $endpoint -SourceObjectId $grant.id -Fields $fields
        $result.Evidence.Add($evidence)
        $audience = if ($grant.consentType -eq 'AllPrincipals') { 'All users' } else { 'Specific user' }
        $node = New-AtlasNode -TenantId $TenantId -Id "oauth2PermissionGrant:$($grant.id)" -Kind oauth2PermissionGrant -DisplayName "$audience delegated consent: $($lookup[$grant.clientId].DisplayName)" -Properties $fields -Source @{ collector = 'delegatedConsent'; resourcePath = "$endpoint/$($grant.id)"; provider = 'microsoftGraph'; apiVersion = 'v1.0' }
        $result.Nodes.Add($node)
        $result.Edges.Add((New-AtlasEdge -TenantId $TenantId -From $lookup[$grant.clientId].Key -To $node.Key -Relationship hasDelegatedConsent -State $fields -EvidenceIds @($evidence.Key) -Source @{ collector = 'delegatedConsent' }))
        $result.Edges.Add((New-AtlasEdge -TenantId $TenantId -From $node.Key -To $lookup[$grant.resourceId].Key -Relationship grantsDelegatedScopes -State $fields -EvidenceIds @($evidence.Key) -Source @{ collector = 'delegatedConsent' }))
        if ($grant.consentType -eq 'Principal') {
            $result.Edges.Add((New-AtlasEdge -TenantId $TenantId -From $lookup[$grant.principalId].Key -To $node.Key -Relationship subjectOfDelegatedConsent -State $fields -EvidenceIds @($evidence.Key) -Source @{ collector = 'delegatedConsent' }))
        }
    }
    $result.Metrics = @{ grantCount = $response.Items.Count; requestCount = $response.Metrics.requestCount; retryCount = $response.Metrics.retryCount }
    return $result
}
