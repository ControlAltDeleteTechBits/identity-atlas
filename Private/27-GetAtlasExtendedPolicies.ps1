function Get-AtlasCrossTenantAccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TenantId
    )

    $result = [AtlasCollectionResult]::new()
    $defaultEndpoint = '/v1.0/policies/crossTenantAccessPolicy/default'
    $partnersEndpoint = '/v1.0/policies/crossTenantAccessPolicy/partners?$expand=identitySynchronization'

    $defaultResponse = Invoke-AtlasGraphRequest -Uri $defaultEndpoint
    $defaultPolicy = @($defaultResponse.Items)[0]
    if ($null -eq $defaultPolicy) {
        $result.Status = 'partial'
        $result.Warnings.Add('The default cross-tenant access policy returned no data.')
        return $result
    }

    $defaultNode = New-AtlasNode -TenantId $TenantId -Id 'crossTenantAccessPolicy:default' -Kind 'crossTenantAccessPolicy' -DisplayName 'Default cross-tenant access settings' -Properties @{
        b2bCollaborationInbound = Get-AtlasResponseProperty -InputObject $defaultPolicy -Name 'b2bCollaborationInbound'
        b2bCollaborationOutbound = Get-AtlasResponseProperty -InputObject $defaultPolicy -Name 'b2bCollaborationOutbound'
        b2bDirectConnectInbound = Get-AtlasResponseProperty -InputObject $defaultPolicy -Name 'b2bDirectConnectInbound'
        b2bDirectConnectOutbound = Get-AtlasResponseProperty -InputObject $defaultPolicy -Name 'b2bDirectConnectOutbound'
        inboundTrust = Get-AtlasResponseProperty -InputObject $defaultPolicy -Name 'inboundTrust'
        automaticUserConsentSettings = Get-AtlasResponseProperty -InputObject $defaultPolicy -Name 'automaticUserConsentSettings'
        tenantRestrictions = Get-AtlasResponseProperty -InputObject $defaultPolicy -Name 'tenantRestrictions'
    } -Source @{
        provider = 'microsoftGraph'
        apiVersion = 'v1.0'
        odataType = '#microsoft.graph.crossTenantAccessPolicyConfigurationDefault'
        resourcePath = '/policies/crossTenantAccessPolicy/default'
        collector = 'crossTenantAccess'
    } -Tags @('externalAccess', 'policy')
    $result.Nodes.Add($defaultNode)

    $defaultEvidence = New-AtlasEvidence -TenantId $TenantId -Collector 'crossTenantAccess' -Endpoint $defaultEndpoint -SourceObjectId 'default' -Fields @{
        policyType = 'default'
        settings = $defaultNode.Properties
    }
    $result.Evidence.Add($defaultEvidence)

    try {
        $partnerResponse = Invoke-AtlasGraphRequest -Uri $partnersEndpoint
    }
    catch {
        $result.Status = 'partial'
        $result.Warnings.Add("Cross-tenant partner settings could not be collected: $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
        $partnerResponse = [pscustomobject] @{
            Items = @()
            Metrics = @{ requestCount = 0; retryCount = 0 }
        }
    }

    foreach ($partner in $partnerResponse.Items) {
        $partnerTenantId = Get-AtlasResponseProperty -InputObject $partner -Name 'tenantId'
        if (-not $partnerTenantId) {
            $partnerTenantId = Get-AtlasResponseProperty -InputObject $partner -Name 'id'
        }
        if (-not $partnerTenantId) {
            $result.Status = 'partial'
            $result.Warnings.Add('A cross-tenant partner configuration without a tenant ID was skipped.')
            continue
        }

        $identitySynchronization = Get-AtlasResponseProperty -InputObject $partner -Name 'identitySynchronization'
        $partnerDisplayName = Get-AtlasResponseProperty -InputObject $identitySynchronization -Name 'displayName'
        if (-not $partnerDisplayName) {
            $partnerDisplayName = "External tenant $partnerTenantId"
        }

        $partnerNode = New-AtlasNode -TenantId $TenantId -Id "externalTenant:$partnerTenantId" -Kind 'externalTenant' -DisplayName $partnerDisplayName -Properties @{
            externalTenantId = $partnerTenantId
            isServiceProvider = Get-AtlasResponseProperty -InputObject $partner -Name 'isServiceProvider'
            b2bCollaborationInbound = Get-AtlasResponseProperty -InputObject $partner -Name 'b2bCollaborationInbound'
            b2bCollaborationOutbound = Get-AtlasResponseProperty -InputObject $partner -Name 'b2bCollaborationOutbound'
            b2bDirectConnectInbound = Get-AtlasResponseProperty -InputObject $partner -Name 'b2bDirectConnectInbound'
            b2bDirectConnectOutbound = Get-AtlasResponseProperty -InputObject $partner -Name 'b2bDirectConnectOutbound'
            inboundTrust = Get-AtlasResponseProperty -InputObject $partner -Name 'inboundTrust'
            automaticUserConsentSettings = Get-AtlasResponseProperty -InputObject $partner -Name 'automaticUserConsentSettings'
            tenantRestrictions = Get-AtlasResponseProperty -InputObject $partner -Name 'tenantRestrictions'
            identitySynchronization = $identitySynchronization
        } -Source @{
            provider = 'microsoftGraph'
            apiVersion = 'v1.0'
            odataType = '#microsoft.graph.crossTenantAccessPolicyConfigurationPartner'
            resourcePath = "/policies/crossTenantAccessPolicy/partners/$partnerTenantId"
            collector = 'crossTenantAccess'
        } -Tags @('externalAccess', 'partnerTenant')
        $result.Nodes.Add($partnerNode)

        $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'crossTenantAccess' -Endpoint $partnersEndpoint -SourceObjectId $partnerTenantId -Fields @{
            partnerTenantId = $partnerTenantId
            settings = $partnerNode.Properties
        }
        $result.Evidence.Add($evidence)
        $result.Edges.Add(
            (New-AtlasEdge -TenantId $TenantId -From $defaultNode.Key -To $partnerNode.Key -Relationship 'hasCrossTenantPartner' -State @{
                partnerTenantId = $partnerTenantId
                userSyncInboundAllowed = Get-AtlasResponseProperty -InputObject (Get-AtlasResponseProperty -InputObject $identitySynchronization -Name 'userSyncInbound') -Name 'isSyncAllowed'
            } -EvidenceIds @($evidence.Key) -Source @{ collector = 'crossTenantAccess' })
        )
    }

    $result.Metrics = @{
        defaultPolicyCount = 1
        partnerCount = $partnerResponse.Items.Count
        requestCount = $defaultResponse.Metrics.requestCount + $partnerResponse.Metrics.requestCount
        retryCount = $defaultResponse.Metrics.retryCount + $partnerResponse.Metrics.retryCount
    }
    return $result
}

function Get-AtlasApplicationManagementPolicy {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TenantId,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AtlasNode[]] $KnownNode
    )

    $result = [AtlasCollectionResult]::new()
    $defaultEndpoint = '/v1.0/policies/defaultAppManagementPolicy'
    $policiesEndpoint = '/v1.0/policies/appManagementPolicies'
    $keyById = @{}
    $applicationNode = @()
    foreach ($node in $KnownNode) {
        $keyById[$node.Id] = $node.Key
        if ($node.Kind -in @('application', 'servicePrincipal')) {
            $applicationNode += $node
        }
    }

    $defaultResponse = Invoke-AtlasGraphRequest -Uri $defaultEndpoint
    $defaultPolicy = @($defaultResponse.Items)[0]
    if ($null -eq $defaultPolicy) {
        $result.Status = 'partial'
        $result.Warnings.Add('The default application management policy returned no data.')
        return $result
    }

    $defaultNode = New-AtlasNode -TenantId $TenantId -Id 'appManagementPolicy:default' -Kind 'applicationManagementPolicy' -DisplayName $(
        $name = Get-AtlasResponseProperty -InputObject $defaultPolicy -Name 'displayName'
        if ($name) { $name } else { 'Default application management policy' }
    ) -Properties @{
        description = Get-AtlasResponseProperty -InputObject $defaultPolicy -Name 'description'
        isEnabled = Get-AtlasResponseProperty -InputObject $defaultPolicy -Name 'isEnabled'
        applicationRestrictions = Get-AtlasResponseProperty -InputObject $defaultPolicy -Name 'applicationRestrictions'
        servicePrincipalRestrictions = Get-AtlasResponseProperty -InputObject $defaultPolicy -Name 'servicePrincipalRestrictions'
        policyType = 'tenantDefault'
    } -Source @{
        provider = 'microsoftGraph'
        apiVersion = 'v1.0'
        odataType = '#microsoft.graph.tenantAppManagementPolicy'
        resourcePath = '/policies/defaultAppManagementPolicy'
        collector = 'applicationManagementPolicies'
    } -Tags @('applicationPolicy', 'defaultPolicy')
    $result.Nodes.Add($defaultNode)

    $policyResponse = Invoke-AtlasGraphRequest -Uri $policiesEndpoint
    $customTargetId = @{}
    foreach ($policy in $policyResponse.Items) {
        $policyNode = New-AtlasNode -TenantId $TenantId -Id "appManagementPolicy:$($policy.id)" -Kind 'applicationManagementPolicy' -DisplayName $policy.displayName -Properties @{
            policyId = $policy.id
            description = Get-AtlasResponseProperty -InputObject $policy -Name 'description'
            isEnabled = Get-AtlasResponseProperty -InputObject $policy -Name 'isEnabled'
            restrictions = Get-AtlasResponseProperty -InputObject $policy -Name 'restrictions'
            policyType = 'custom'
        } -Source @{
            provider = 'microsoftGraph'
            apiVersion = 'v1.0'
            odataType = '#microsoft.graph.appManagementPolicy'
            resourcePath = "/policies/appManagementPolicies/$($policy.id)"
            collector = 'applicationManagementPolicies'
        } -Tags @('applicationPolicy', 'customPolicy')
        $result.Nodes.Add($policyNode)

        $appliesToEndpoint = "/v1.0/policies/appManagementPolicies/$($policy.id)/appliesTo?`$select=id,appId,displayName,createdDateTime"
        try {
            $appliesToResponse = Invoke-AtlasGraphRequest -Uri $appliesToEndpoint
            $policyResponse.Metrics.requestCount += $appliesToResponse.Metrics.requestCount
            $policyResponse.Metrics.retryCount += $appliesToResponse.Metrics.retryCount
        }
        catch {
            $result.Status = 'partial'
            $result.Warnings.Add("Applications governed by policy '$($policy.displayName)' could not be collected: $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
            continue
        }

        foreach ($target in $appliesToResponse.Items) {
            $targetId = Get-AtlasResponseProperty -InputObject $target -Name 'id'
            if (-not $targetId) {
                continue
            }
            $customTargetId[$targetId] = $true
            if ($keyById.ContainsKey($targetId)) {
                $targetKey = $keyById[$targetId]
            }
            else {
                $odataType = Get-AtlasResponseProperty -InputObject $target -Name '@odata.type'
                $targetKind = if ($odataType -eq '#microsoft.graph.application') { 'application' } else { 'servicePrincipal' }
                $targetName = Get-AtlasResponseProperty -InputObject $target -Name 'displayName'
                if (-not $targetName) { $targetName = $targetId }
                $targetNode = New-AtlasNode -TenantId $TenantId -Id $targetId -Kind $targetKind -DisplayName $targetName -Status 'partial' -Source @{
                    provider = 'microsoftGraph'
                    apiVersion = 'v1.0'
                    odataType = $odataType
                    resourcePath = "/directoryObjects/$targetId"
                    collector = 'applicationManagementPolicies'
                }
                $result.Nodes.Add($targetNode)
                $targetKey = $targetNode.Key
            }

            $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'applicationManagementPolicies' -Endpoint $appliesToEndpoint -SourceObjectId "$targetId|$($policy.id)" -Fields @{
                targetId = $targetId
                policyId = $policy.id
                policyType = 'custom'
            }
            $result.Evidence.Add($evidence)
            $result.Edges.Add(
                (New-AtlasEdge -TenantId $TenantId -From $targetKey -To $policyNode.Key -Relationship 'governedByAppManagementPolicy' -State @{
                    assignment = 'explicit'
                    policyEnabled = Get-AtlasResponseProperty -InputObject $policy -Name 'isEnabled'
                } -EvidenceIds @($evidence.Key) -Source @{ collector = 'applicationManagementPolicies' })
            )
        }
    }

    foreach ($node in $applicationNode) {
        if ($customTargetId.ContainsKey($node.Id)) {
            continue
        }
        $evidence = New-AtlasEvidence -TenantId $TenantId -Collector 'applicationManagementPolicies' -Endpoint $defaultEndpoint -SourceObjectId "$($node.Id)|default" -Fields @{
            targetId = $node.Id
            policyId = 'default'
            policyType = 'tenantDefault'
            appliesByDefault = $true
        }
        $result.Evidence.Add($evidence)
        $result.Edges.Add(
            (New-AtlasEdge -TenantId $TenantId -From $node.Key -To $defaultNode.Key -Relationship 'governedByDefaultAppManagementPolicy' -State @{
                assignment = 'default'
                policyEnabled = Get-AtlasResponseProperty -InputObject $defaultPolicy -Name 'isEnabled'
            } -EvidenceIds @($evidence.Key) -Source @{ collector = 'applicationManagementPolicies'; inference = 'documentedDefault' })
        )
    }

    $result.Metrics = @{
        defaultPolicyCount = 1
        customPolicyCount = $policyResponse.Items.Count
        explicitlyGovernedObjectCount = $customTargetId.Count
        defaultGovernedObjectCount = @($applicationNode | Where-Object { -not $customTargetId.ContainsKey($_.Id) }).Count
        requestCount = $defaultResponse.Metrics.requestCount + $policyResponse.Metrics.requestCount
        retryCount = $defaultResponse.Metrics.retryCount + $policyResponse.Metrics.retryCount
    }
    return $result
}
