Describe 'Identity Atlas community release controls' {
    BeforeAll {
        $script:projectRoot = Split-Path -Parent $PSScriptRoot
    }

    It 'uses the approved publisher metadata' {
        $manifest = Import-PowerShellDataFile -Path (Join-Path $script:projectRoot 'IdentityAtlas.psd1')

        $manifest.Author | Should -Be 'Mark Oldham'
        $manifest.CompanyName | Should -Be 'Control Alt Delete Tech Bits'
        $manifest.Copyright | Should -Match 'Control Alt Delete Tech Bits'
        $manifest.PrivateData.PSData.Prerelease | Should -Be 'preview1'
    }

    It 'contains the required community files' {
        $requiredFiles = @(
            'CHANGELOG.md'
            'CODE_OF_CONDUCT.md'
            'CONTRIBUTING.md'
            'LICENSE'
            'README.md'
            'SECURITY.md'
            'SUPPORT.md'
            'THIRD-PARTY-NOTICES.md'
        )

        foreach ($fileName in $requiredFiles) {
            Test-Path -LiteralPath (Join-Path $script:projectRoot $fileName) | Should -Be $true
        }
    }

    It 'excludes generated reports and release archives from Git' {
        $gitIgnore = Get-Content -LiteralPath (Join-Path $script:projectRoot '.gitignore') -Raw

        $gitIgnore | Should -Match '(?m)^Output/\r?$'
        $gitIgnore | Should -Match '(?m)^Release/\r?$'
        $gitIgnore | Should -Match '(?m)^\*\.zip\r?$'
        $gitIgnore | Should -Match '(?m)^\*\.pfx\r?$'
    }

    It 'provides issue and pull request templates' {
        Test-Path -LiteralPath (Join-Path $script:projectRoot '.github/ISSUE_TEMPLATE/bug_report.yml') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $script:projectRoot '.github/ISSUE_TEMPLATE/feature_request.yml') | Should -Be $true
        Test-Path -LiteralPath (Join-Path $script:projectRoot '.github/PULL_REQUEST_TEMPLATE.md') | Should -Be $true
    }

    It 'keeps the validation workflow read only' {
        $workflow = Get-Content -LiteralPath (Join-Path $script:projectRoot '.github/workflows/validate.yml') -Raw

        $workflow | Should -Match '(?m)^\s*contents:\s*read\s*$'
        $workflow | Should -Not -Match '(?m)^\s*contents:\s*write\s*$'
        $workflow | Should -Match 'persist-credentials:\s*false'
    }

    It 'passes the release safety scan' {
        $result = & (Join-Path $script:projectRoot 'tools/Test-IdentityAtlasRelease.ps1') -Path $script:projectRoot

        $result.Findings | Should -Be 0
        $result.Status | Should -Be 'Passed'
    }

    It 'rejects tenant and credential shaped content' {
        $unsafeRoot = Join-Path $TestDrive 'UnsafeRelease'
        New-Item -ItemType Directory -Path $unsafeRoot | Out-Null
        $unsafeContent = @(
            ('administrator@exampletenant.' + 'onmicrosoft.com')
            ('access_' + 'token=notarealtokenvalue')
        )
        $unsafeContent | Set-Content -LiteralPath (Join-Path $unsafeRoot 'unsafe.md')

        $scanRejectedContent = $false
        try {
            & (Join-Path $script:projectRoot 'tools/Test-IdentityAtlasRelease.ps1') -Path $unsafeRoot -WarningAction SilentlyContinue
        }
        catch {
            $scanRejectedContent = $true
        }

        $scanRejectedContent | Should -Be $true
    }
}
