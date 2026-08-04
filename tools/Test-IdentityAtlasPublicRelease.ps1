[CmdletBinding()]
param(
    [string] $Path,

    [string] $ReleasePath,

    [string[]] $ExpectedAuthor = @(
        'Mark Oldham'
        'MarkCADTB'
    ),

    [string[]] $ExpectedCommitter = @(
        'Mark Oldham'
        'MarkCADTB'
        'GitHub'
    ),

    [string] $ExpectedEmail = 'Mark@controlaltdeletetechbits.co.uk',

    [string] $ExpectedGitHubCommitterEmail = 'noreply@github.com',

    [switch] $SkipHistory,

    [switch] $SkipPackage
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Path) {
    $Path = Split-Path -Parent $PSScriptRoot
}

$projectRoot = [System.IO.Path]::GetFullPath($Path)
if (-not [System.IO.Directory]::Exists($projectRoot)) {
    throw "Project path does not exist: $projectRoot"
}

$checks = [System.Collections.Generic.List[object]]::new()

function Add-AtlasPublicReleaseCheck {
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [bool] $Passed,

        [Parameter(Mandatory)]
        [string] $Evidence
    )

    $checks.Add([pscustomobject] @{
        Name = $Name
        Passed = $Passed
        Evidence = $Evidence
    })

    if (-not $Passed) {
        throw "Public release security check failed: $Name. $Evidence"
    }
}

function Get-AtlasFileText {
    param(
        [Parameter(Mandatory)]
        [string] $RelativePath
    )

    $filePath = Join-Path $projectRoot $RelativePath
    if (-not [System.IO.File]::Exists($filePath)) {
        throw "Required security review file is missing: $RelativePath"
    }

    return [System.IO.File]::ReadAllText($filePath)
}

function Invoke-AtlasGit {
    param(
        [Parameter(Mandatory)]
        [string[]] $ArgumentList
    )

    $output = @(& git -C $projectRoot @ArgumentList 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "Git command failed: git $($ArgumentList -join ' ')`n$($output -join [Environment]::NewLine)"
    }

    return $output
}

$sourceScan = & (Join-Path $PSScriptRoot 'Test-IdentityAtlasRelease.ps1') -Path $projectRoot
Add-AtlasPublicReleaseCheck -Name 'Current source safety scan' -Passed ($sourceScan.Findings -eq 0) -Evidence "$($sourceScan.ScannedFiles) text files scanned with zero findings."

$trackedFiles = @(Invoke-AtlasGit -ArgumentList @('ls-files'))
$forbiddenTrackedPaths = @(
    $trackedFiles | Where-Object {
        $_ -match '(?i)(^|/)(Output|Release|Gallery|TestResults|work|attachments|\.codex)(/|$)' -or
        $_ -match '(?i)(^|/)data/report\.json$' -or
        $_ -match '(?i)\.(pfx|p12|key|cer|crt|zip|nupkg)$'
    }
)
Add-AtlasPublicReleaseCheck -Name 'Tracked path boundary' -Passed ($forbiddenTrackedPaths.Count -eq 0) -Evidence $(
    if ($forbiddenTrackedPaths.Count -eq 0) {
        "$($trackedFiles.Count) tracked paths contain no report, archive, certificate or workspace output."
    }
    else {
        "Forbidden tracked paths: $($forbiddenTrackedPaths -join ', ')"
    }
)

$scopeModule = Import-Module (Join-Path $projectRoot 'IdentityAtlas.psd1') -Force -PassThru
$defaultScopes = @(& $scopeModule { Get-AtlasRecommendedScope -CollectionProfile Core })
$governanceScopes = @(& $scopeModule { Get-AtlasRecommendedScope -CollectionProfile Governance })
$requestedScopes = @($defaultScopes + $governanceScopes | Sort-Object -Unique)
$unsafeScopes = @($requestedScopes | Where-Object { $_ -match '(?i)ReadWrite|\.Write|FullControl' })
Add-AtlasPublicReleaseCheck -Name 'Delegated Graph scope boundary' -Passed (
    $defaultScopes.Count -gt 0 -and $unsafeScopes.Count -eq 0
) -Evidence $(
    if ($unsafeScopes.Count -eq 0) {
        "Core and opt-in Governance delegated scopes are read only. Core: $($defaultScopes -join ', '). Governance total: $($governanceScopes -join ', ')."
    }
    else {
        "Unsafe default scopes: $($unsafeScopes -join ', ')"
    }
)

$powerShellFiles = @(
    Get-ChildItem -LiteralPath $projectRoot -Recurse -File -Include *.ps1, *.psm1 |
        Where-Object {
            $_.FullName -notmatch '(?i)[\\/](Output|Release|Gallery|TestResults|work|attachments|\.git)[\\/]' -and
            $_.FullName -ne $PSCommandPath
        }
)
$powerShellText = ($powerShellFiles | ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) }) -join [Environment]::NewLine
$unsafePowerShellPrimitives = @(
    @(
        'Invoke-Expression'
        'Invoke-Command'
    ) | Where-Object { $powerShellText -match "(?i)\b$([regex]::Escape($_))\b" }
)
Add-AtlasPublicReleaseCheck -Name 'PowerShell execution boundary' -Passed ($unsafePowerShellPrimitives.Count -eq 0) -Evidence $(
    if ($unsafePowerShellPrimitives.Count -eq 0) {
        'No dynamic code evaluation or PowerShell remoting primitive is present in the reviewed source.'
    }
    else {
        "Review required for: $($unsafePowerShellPrimitives -join ', ')"
    }
)

$graphRequestScript = Get-AtlasFileText -RelativePath 'Private\10-InvokeAtlasGraphRequest.ps1'
$nonGetGraphCalls = @(
    [regex]::Matches(
        $graphRequestScript,
        '(?im)Invoke-MgGraphRequest[^\r\n]*-Method\s+(?!GET\b)[A-Z]+'
    )
)
Add-AtlasPublicReleaseCheck -Name 'Microsoft Graph request methods' -Passed ($nonGetGraphCalls.Count -eq 0) -Evidence 'The live Graph request wrapper only issues GET requests.'

$appJavaScript = Get-AtlasFileText -RelativePath 'Web\assets\app.js'
$dataRuntimeJavaScript = Get-AtlasFileText -RelativePath 'Web\assets\data-runtime.js'
$workerJavaScript = Get-AtlasFileText -RelativePath 'Web\assets\graph-worker-source.js'
$browserJavaScript = @($appJavaScript, $dataRuntimeJavaScript, $workerJavaScript) -join [Environment]::NewLine
$unsafeBrowserPatterns = [ordered] @{
    'HTML string injection' = '(?i)\b(innerHTML|outerHTML|insertAdjacentHTML)\b'
    'Document stream writing' = '(?i)\bdocument\.write(?:ln)?\s*\('
    'Dynamic JavaScript evaluation' = '(?i)(?:\beval\s*\(|\bnew\s+Function\s*\()'
    'Browser network request' = '(?i)(?:\bfetch\s*\(|\bXMLHttpRequest\b|\bWebSocket\s*\(|\bsendBeacon\s*\()'
}
$unsafeBrowserFindings = @(
    foreach ($entry in $unsafeBrowserPatterns.GetEnumerator()) {
        if ($browserJavaScript -match $entry.Value) {
            $entry.Key
        }
    }
)
Add-AtlasPublicReleaseCheck -Name 'Offline browser execution boundary' -Passed ($unsafeBrowserFindings.Count -eq 0) -Evidence $(
    if ($unsafeBrowserFindings.Count -eq 0) {
        'No HTML string injection, dynamic evaluation or browser network API is used by the report.'
    }
    else {
        "Unsafe browser patterns: $($unsafeBrowserFindings -join ', ')"
    }
)

$indexHtml = Get-AtlasFileText -RelativePath 'Web\index.html'
$cspPassed = (
    $indexHtml -match "default-src 'none'" -and
    $indexHtml -match "connect-src 'none'" -and
    $indexHtml -match "object-src 'none'" -and
    $indexHtml -match "base-uri 'none'" -and
    $indexHtml -match "form-action 'none'"
)
Add-AtlasPublicReleaseCheck -Name 'Report Content Security Policy' -Passed $cspPassed -Evidence 'The offline report blocks network connections, objects, base URL changes and form submission.'

$workflowText = Get-AtlasFileText -RelativePath '.github\workflows\validate.yml'
$workflowPassed = (
    $workflowText -match '(?m)^\s*contents:\s*read\s*$' -and
    $workflowText -notmatch '(?im)^\s*[A-Za-z-]+:\s*write\s*$' -and
    $workflowText -notmatch '(?im)^\s*pull_request_target\s*:' -and
    $workflowText -match '(?m)^\s*persist-credentials:\s*false\s*$' -and
    $workflowText -notmatch '(?m)^\s*uses:\s*[^@\r\n]+@(?![0-9a-f]{40}(?:\s|#|$))'
)
Add-AtlasPublicReleaseCheck -Name 'GitHub Actions trust boundary' -Passed $workflowPassed -Evidence 'The workflow has read-only permissions, does not persist Git credentials and pins actions to full commit identifiers.'

$commitCount = 0
if (-not $SkipHistory) {
    $commitRows = @(Invoke-AtlasGit -ArgumentList @('log', '--all', '--format=%H|%an|%ae|%cn|%ce'))
    $unexpectedIdentity = @(
        foreach ($row in $commitRows) {
            $parts = $row -split '\|', 5
            $authorApproved = (
                $parts.Count -eq 5 -and
                $parts[1] -cin $ExpectedAuthor -and
                $parts[2] -ceq $ExpectedEmail
            )
            $directCommitterApproved = (
                $parts.Count -eq 5 -and
                $parts[3] -cin @('Mark Oldham', 'MarkCADTB') -and
                $parts[4] -ceq $ExpectedEmail
            )
            $githubCommitterApproved = (
                $parts.Count -eq 5 -and
                $parts[3] -ceq 'GitHub' -and
                $parts[4] -ceq $ExpectedGitHubCommitterEmail
            )
            if (
                -not $authorApproved -or
                $parts[3] -cnotin $ExpectedCommitter -or
                (-not $directCommitterApproved -and -not $githubCommitterApproved)
            ) {
                $row
            }
        }
    )
    Add-AtlasPublicReleaseCheck -Name 'Git history authorship' -Passed ($unexpectedIdentity.Count -eq 0) -Evidence $(
        if ($unexpectedIdentity.Count -eq 0) {
            "$($commitRows.Count) commits have the approved Mark identity or the exact GitHub protected-merge identity."
        }
        else {
            "Unexpected history identity: $($unexpectedIdentity -join ', ')"
        }
    )

    $temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $temporaryPrefix = $temporaryRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $historyRoot = [System.IO.Path]::GetFullPath(
        (Join-Path $temporaryRoot "IdentityAtlasHistoryAudit-$([guid]::NewGuid().ToString('N'))")
    )
    if (-not $historyRoot.StartsWith($temporaryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'The history audit path is outside the system temporary directory.'
    }

    try {
        [System.IO.Directory]::CreateDirectory($historyRoot) | Out-Null
        foreach ($commitRow in $commitRows) {
            $commit = ($commitRow -split '\|', 2)[0]
            $commitRoot = Join-Path $historyRoot $commit
            $archivePath = Join-Path $historyRoot "$commit.zip"
            [System.IO.Directory]::CreateDirectory($commitRoot) | Out-Null
            Invoke-AtlasGit -ArgumentList @('archive', '--format=zip', "--output=$archivePath", $commit) | Out-Null
            Expand-Archive -LiteralPath $archivePath -DestinationPath $commitRoot
            & (Join-Path $PSScriptRoot 'Test-IdentityAtlasRelease.ps1') -Path $commitRoot | Out-Null
            $commitCount++
        }
        Add-AtlasPublicReleaseCheck -Name 'Complete Git history content' -Passed ($commitCount -eq $commitRows.Count) -Evidence "$commitCount historical snapshots passed the tenant-data and secret scan."
    }
    finally {
        if ([System.IO.Directory]::Exists($historyRoot)) {
            $validatedHistoryRoot = [System.IO.Path]::GetFullPath($historyRoot)
            if (-not $validatedHistoryRoot.StartsWith($temporaryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw 'Refusing to remove a history audit directory outside the system temporary directory.'
            }
            [System.IO.Directory]::Delete($validatedHistoryRoot, $true)
        }
    }
}

$packagePath = $null
$packageHash = $null
if (-not $SkipPackage) {
    if (-not $ReleasePath) {
        $releaseDirectory = Join-Path $projectRoot 'Release'
        $releaseCandidate = @(
            Get-ChildItem -LiteralPath $releaseDirectory -File -Filter 'IdentityAtlas-v*.zip' |
                Sort-Object LastWriteTimeUtc -Descending
        )
        if ($releaseCandidate.Count -ne 1) {
            throw 'Pass -ReleasePath when the Release directory does not contain exactly one Identity Atlas ZIP.'
        }
        $ReleasePath = $releaseCandidate[0].FullName
    }
    elseif (-not [System.IO.Path]::IsPathRooted($ReleasePath)) {
        $ReleasePath = Join-Path $projectRoot $ReleasePath
    }

    $packagePath = [System.IO.Path]::GetFullPath($ReleasePath)
    if (-not [System.IO.File]::Exists($packagePath)) {
        throw "Release package does not exist: $packagePath"
    }

    $checksumPath = Join-Path ([System.IO.Path]::GetDirectoryName($packagePath)) (
        [System.IO.Path]::GetFileNameWithoutExtension($packagePath) + '-SHA256.txt'
    )
    if (-not [System.IO.File]::Exists($checksumPath)) {
        throw "Release checksum file does not exist: $checksumPath"
    }

    $checksumText = [System.IO.File]::ReadAllText($checksumPath).Trim()
    $expectedHashMatch = [regex]::Match($checksumText, '^(?<hash>[0-9A-Fa-f]{64})\s+')
    if (-not $expectedHashMatch.Success) {
        throw 'The release checksum file does not contain a valid SHA256 value.'
    }

    $packageHash = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash
    Add-AtlasPublicReleaseCheck -Name 'Release package checksum' -Passed (
        $packageHash -ceq $expectedHashMatch.Groups['hash'].Value.ToUpperInvariant()
    ) -Evidence "SHA256 $packageHash matches the release checksum file."

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [System.IO.Compression.ZipFile]::OpenRead($packagePath)
    try {
        $unsafeEntries = @(
            $archive.Entries | Where-Object {
                $_.FullName -match '(?i)(^|/)(Output|Release|Tests|TestResults|work|attachments|\.codex|\.git)(/|$)' -or
                $_.FullName -match '(?i)(^|/)data/report\.json$' -or
                $_.FullName -match '(?i)\.(pfx|p12|key|cer|crt)$'
            }
        )
    }
    finally {
        $archive.Dispose()
    }
    Add-AtlasPublicReleaseCheck -Name 'Release archive contents' -Passed ($unsafeEntries.Count -eq 0) -Evidence 'The archive contains no tenant report, test fixture, workspace output, Git metadata or certificate file.'

    $temporaryRoot = [System.IO.Path]::GetFullPath([System.IO.Path]::GetTempPath())
    $temporaryPrefix = $temporaryRoot.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $packageRoot = [System.IO.Path]::GetFullPath(
        (Join-Path $temporaryRoot "IdentityAtlasPackageAudit-$([guid]::NewGuid().ToString('N'))")
    )
    if (-not $packageRoot.StartsWith($temporaryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'The package audit path is outside the system temporary directory.'
    }

    try {
        [System.IO.Directory]::CreateDirectory($packageRoot) | Out-Null
        Expand-Archive -LiteralPath $packagePath -DestinationPath $packageRoot
        $extractedModuleRoot = Join-Path $packageRoot 'IdentityAtlas'
        $packageScan = & (Join-Path $PSScriptRoot 'Test-IdentityAtlasRelease.ps1') -Path $extractedModuleRoot
        Test-ModuleManifest -Path (Join-Path $extractedModuleRoot 'IdentityAtlas.psd1') | Out-Null
        Add-AtlasPublicReleaseCheck -Name 'Extracted package validation' -Passed ($packageScan.Findings -eq 0) -Evidence "$($packageScan.ScannedFiles) packaged text files passed the safety scan and the module manifest is valid."
    }
    finally {
        if ([System.IO.Directory]::Exists($packageRoot)) {
            $validatedPackageRoot = [System.IO.Path]::GetFullPath($packageRoot)
            if (-not $validatedPackageRoot.StartsWith($temporaryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw 'Refusing to remove a package audit directory outside the system temporary directory.'
            }
            [System.IO.Directory]::Delete($validatedPackageRoot, $true)
        }
    }
}

[pscustomobject] @{
    ProjectRoot = $projectRoot
    Status = 'Passed'
    CheckCount = $checks.Count
    CommitCount = $commitCount
    PackagePath = $packagePath
    PackageSha256 = $packageHash
    Checks = @($checks)
}
