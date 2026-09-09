function Stop-IdentityAtlasReport {
    <#
    .SYNOPSIS
    Stops an Identity Atlas server started by this module session.
    .EXAMPLE
    Stop-IdentityAtlasReport -ProcessId $server.ProcessId
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)] [int] $ProcessId)
    $registry = Get-Variable AtlasReportServers -Scope Script -ErrorAction SilentlyContinue
    if (-not $registry -or -not $registry.Value.ContainsKey($ProcessId)) {
        throw 'This server is not registered in the current module session. No process was stopped.'
    }
    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if ($process -and $process.StartTime.ToUniversalTime().Ticks -ne $registry.Value[$ProcessId]) {
        throw 'The process identifier has been reused. No process was stopped.'
    }
    if ($PSCmdlet.ShouldProcess("Identity Atlas server $ProcessId", 'Stop')) {
        if ($process) { Stop-Process -InputObject $process -ErrorAction Stop }
        $registry.Value.Remove($ProcessId)
    }
}
