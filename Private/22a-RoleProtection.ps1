function Add-AtlasRoleProtectionEvidence {
    [CmdletBinding()]
    param([string] $TenantId, [AtlasCollectionResult] $Result)

    $metrics = @{ requestCount = 0; retryCount = 0 }
    $endpoints = @{
        schedules = '/v1.0/roleManagement/directory/roleAssignmentScheduleInstances?$select=id,roleAssignmentOriginId,principalId,roleDefinitionId,directoryScopeId,appScopeId,assignmentType,startDateTime,endDateTime,memberType'
        policies = '/v1.0/policies/roleManagementPolicyAssignments?$filter=scopeId%20eq%20%27/%27%20and%20scopeType%20eq%20%27DirectoryRole%27&$expand=policy($expand=rules)'
    }
    foreach ($kind in @('schedules', 'policies')) {
        try {
            $response = Invoke-AtlasGraphRequest -Uri $endpoints[$kind]
            $metrics.requestCount += $response.Metrics.requestCount
            $metrics.retryCount += $response.Metrics.retryCount
            foreach ($item in $response.Items) {
                if ($kind -eq 'schedules') {
                    $origin = Get-AtlasResponseProperty -InputObject $item -Name roleAssignmentOriginId
                    if (-not $origin) { continue }
                    foreach ($edge in $Result.Edges) {
                        if ($edge.Relationship -ne 'assignedRole' -or $edge.State.assignmentId -ne $origin) { continue }
                        $fields = @{}
                        foreach ($field in @('assignmentType', 'startDateTime', 'endDateTime', 'memberType', 'roleAssignmentOriginId')) {
                            $fields[$field] = Get-AtlasResponseProperty -InputObject $item -Name $field
                        }
                        $evidence = New-AtlasEvidence -TenantId $TenantId -Collector directoryRoleProtection -Endpoint $endpoints[$kind] -SourceObjectId $item.id -Fields $fields
                        $Result.Evidence.Add($evidence)
                        # Preserve all matching instances; overlapping schedules must not overwrite one another.
                        if (-not $edge.State.ContainsKey('scheduleInstances')) { $edge.State.scheduleInstances = @() }
                        $edge.State.scheduleInstances += $fields
                        $edge.EvidenceIds = @($edge.EvidenceIds) + @($evidence.Key)
                    }
                }
                else {
                    $policy = Get-AtlasResponseProperty -InputObject $item -Name policy
                    $rules = @(Get-AtlasResponseProperty -InputObject $policy -Name rules | Where-Object { $null -ne $_ })
                    foreach ($role in $Result.Nodes) {
                        if ($role.Kind -ne 'roleDefinition' -or $role.Id -ne $item.roleDefinitionId) { continue }
                        $fields = @{ policyId = $item.policyId; scopeId = $item.scopeId; scopeType = $item.scopeType; rules = $rules }
                        $evidence = New-AtlasEvidence -TenantId $TenantId -Collector directoryRoleProtection -Endpoint $endpoints[$kind] -SourceObjectId $item.id -Fields $fields
                        if (-not $rules.Count -or (Get-AtlasResponseProperty -InputObject $policy -Name 'rules@odata.nextLink')) {
                            $evidence.Completeness = 'partial'
                            $Result.Status = 'partial'
                            $Result.Warnings.Add('A PIM role policy has missing or incomplete expanded rules. Activation requirements remain unverified.')
                        }
                        $Result.Evidence.Add($evidence)
                        if (-not $role.Properties.ContainsKey('pimPolicies')) { $role.Properties.pimPolicies = @() }
                        $role.Properties.pimPolicies += @{ policyId = $item.policyId; scopeId = $item.scopeId; rules = $rules; evidenceId = $evidence.Key }
                    }
                }
            }
        }
        catch [System.Management.Automation.PipelineStoppedException] { throw }
        catch [System.OperationCanceledException] { throw }
        catch {
            $Result.Status = 'partial'
            $Result.Warnings.Add("PIM protection $kind evidence could not be collected: $(Get-AtlasSafeErrorDetail -ErrorRecord $_)")
        }
    }
    return $metrics
}
