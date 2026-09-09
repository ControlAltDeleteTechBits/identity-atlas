function Open-IdentityAtlasReport {
    <#
    .SYNOPSIS
    Reopens an existing local tenant report without Microsoft Graph authentication.
    .EXAMPLE
    $server = Open-IdentityAtlasReport -Path .\TenantReport
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [ValidateRange(1024, 65535)] [int] $Port = 8766,
        [ValidateRange(0, 50)] [int] $PortSearchLimit = 20,
        [switch] $NoBrowser
    )
    Start-AtlasReportServer -ReportRoot $Path -Port $Port -PortSearchLimit $PortSearchLimit -OpenBrowser:(-not $NoBrowser)
}
