function Get-AtlasUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TenantId
    )

    $result = [AtlasCollectionResult]::new()
    $endpoint = '/v1.0/users?$select=id,displayName,userPrincipalName,userType,accountEnabled'
    $response = Invoke-AtlasGraphRequest -Uri $endpoint

    foreach ($user in $response.Items) {
        $properties = @{
            userPrincipalName = $user.userPrincipalName
            userType = $user.userType
            accountEnabled = $user.accountEnabled
        }
        $kind = if ($user.userType -eq 'Guest') { 'guestUser' } else { 'user' }
        $node = New-AtlasNode -TenantId $TenantId -Id $user.id -Kind $kind -DisplayName $user.displayName -Properties $properties -Source @{
            provider = 'microsoftGraph'
            apiVersion = 'v1.0'
            odataType = '#microsoft.graph.user'
            resourcePath = "/users/$($user.id)"
            collector = 'users'
        }
        $result.Nodes.Add($node)
    }

    $result.Metrics = $response.Metrics
    return $result
}
