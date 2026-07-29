[CmdletBinding()]
param(
    [switch] $SkipTests,

    [string] $NodePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = $PSScriptRoot
$identityAtlasModule = Import-Module (Join-Path $projectRoot 'IdentityAtlas.psd1') -Force -PassThru
$moduleManifest = Test-ModuleManifest -Path (Join-Path $projectRoot 'IdentityAtlas.psd1')
$pesterResult = $null

if (-not $SkipTests) {
    & (Join-Path $projectRoot 'tools/Test-IdentityAtlasRelease.ps1') -Path $projectRoot | Out-Null

    $pester = Get-Module -ListAvailable Pester |
        Where-Object { $_.Version -ge [version] '5.5.0' -and $_.Version -lt [version] '6.0.0' } |
        Sort-Object Version -Descending |
        Select-Object -First 1
    if (-not $pester) {
        throw 'Pester 5.5.0 or later in the 5.x series is required to run the PowerShell test suite.'
    }

    Import-Module $pester.Path -Force

    $scriptAnalyzer = Get-Module -ListAvailable PSScriptAnalyzer |
        Sort-Object Version -Descending |
        Select-Object -First 1
    if ($scriptAnalyzer) {
        Import-Module $scriptAnalyzer.Path -Force
        $analysisFindings = @(Invoke-ScriptAnalyzer -Path $projectRoot -Recurse -Severity Error, Warning)
        if ($analysisFindings.Count -gt 0) {
            $analysisFindings | Format-Table RuleName, Severity, ScriptName, Line, Message -Wrap
            throw "$($analysisFindings.Count) PSScriptAnalyzer finding or findings must be resolved."
        }
    }
    else {
        Write-Warning 'PSScriptAnalyzer is not installed, so static PowerShell analysis was skipped.'
    }

    $pesterResult = Invoke-Pester -Path (Join-Path $projectRoot 'Tests') -PassThru
    if ($pesterResult.FailedCount -gt 0) {
        throw "$($pesterResult.FailedCount) Pester test or tests failed."
    }

    if (-not $NodePath) {
        $nodeCommand = Get-Command node -ErrorAction SilentlyContinue
        if ($nodeCommand) {
            $NodePath = $nodeCommand.Source
        }
    }
    if (-not $NodePath -or -not (Test-Path -LiteralPath $NodePath)) {
        throw 'Node.js was not found. Pass its executable path through -NodePath to run JavaScript tests.'
    }

    & $NodePath --check (Join-Path $projectRoot 'Web/assets/app.js')
    if ($LASTEXITCODE -ne 0) {
        throw 'JavaScript syntax validation failed.'
    }

    $temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $workerTestRoot = [System.IO.Path]::GetFullPath(
        (Join-Path $temporaryRoot "IdentityAtlasWorkerTest-$([guid]::NewGuid().ToString('N'))")
    )
    $temporaryPrefix = $temporaryRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    if (-not $workerTestRoot.StartsWith($temporaryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'The worker test output path is outside the system temporary directory.'
    }

    try {
        & $identityAtlasModule {
            param($TestFixturePath, $TestOutputPath)

            . $TestFixturePath
            $fixture = Get-AtlasTestData
            $report = New-AtlasReport -TenantId $fixture.TenantId -TenantDisplayName $fixture.TenantDisplayName -Collection $fixture.Collection -Collectors $fixture.Collectors -DataOrigin SampleFixture
            Write-AtlasReport -Report $report -OutputPath $TestOutputPath | Out-Null
        } (Join-Path $projectRoot 'Tests/Fixtures/Get-AtlasTestData.ps1') $workerTestRoot

        $env:IDENTITY_ATLAS_TEST_REPORT = Join-Path $workerTestRoot 'data/report.json'
        & $NodePath --test (Join-Path $projectRoot 'Tests/GraphWorker.test.mjs')
        if ($LASTEXITCODE -ne 0) {
            throw 'The graph worker test suite failed.'
        }
    }
    finally {
        Remove-Item Env:IDENTITY_ATLAS_TEST_REPORT -ErrorAction SilentlyContinue
        if ([System.IO.Directory]::Exists($workerTestRoot)) {
            [System.IO.Directory]::Delete($workerTestRoot, $true)
        }
    }
}

[pscustomobject] @{
    ProjectRoot = $projectRoot
    ModuleVersion = $moduleManifest.Version.ToString()
    PowerShellTests = if ($pesterResult) { $pesterResult.PassedCount } else { 'Skipped' }
    JavaScriptTests = if ($SkipTests) { 'Skipped' } else { 8 }
}
