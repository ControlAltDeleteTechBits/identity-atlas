Set-StrictMode -Version Latest

$moduleRoot = $PSScriptRoot

. (Join-Path $moduleRoot 'Private/Types.ps1')

Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'Private') -Filter '*.ps1' -File |
    Where-Object Name -ne 'Types.ps1' |
    Sort-Object Name |
    ForEach-Object { . $_.FullName }

Get-ChildItem -LiteralPath (Join-Path $moduleRoot 'Public') -Filter '*.ps1' -File |
    Sort-Object Name |
    ForEach-Object { . $_.FullName }

Export-ModuleMember -Function @(
    'Connect-IdentityAtlas'
    'Invoke-IdentityAtlas'
    'Export-IdentityAtlas'
    'Compare-IdentityAtlas'
)
