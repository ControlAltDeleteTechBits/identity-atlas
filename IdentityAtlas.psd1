@{
    RootModule        = 'IdentityAtlas.psm1'
    ModuleVersion     = '1.1.0'
    GUID              = 'f0ce5f0e-34dc-4c59-9c12-3e35b581e955'
    Author            = 'Mark Oldham'
    CompanyName       = 'Control Alt Delete Tech Bits'
    Copyright         = '(c) 2026 Control Alt Delete Tech Bits. MIT licensed.'
    Description       = 'A local visual explorer for Microsoft Entra objects, relationships and access paths.'
    PowerShellVersion = '7.0'
    CompatiblePSEditions = @('Core')
    RequiredModules   = @(
        @{
            ModuleName = 'Microsoft.Graph.Authentication'
            ModuleVersion = '2.38.1'
        }
    )
    FunctionsToExport = @(
        'Connect-IdentityAtlas'
        'Invoke-IdentityAtlas'
        'Export-IdentityAtlas'
        'Compare-IdentityAtlas'
        'Open-IdentityAtlasReport'
        'Stop-IdentityAtlasReport'
        'Test-IdentityAtlasConnection'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('MicrosoftEntra', 'MicrosoftGraph', 'Microsoft365', 'Identity', 'Security', 'Visualisation', 'PSEdition_Core')
            LicenseUri   = 'https://github.com/ControlAltDeleteTechBits/identity-atlas/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/ControlAltDeleteTechBits/identity-atlas'
            IconUri      = 'https://raw.githubusercontent.com/ControlAltDeleteTechBits/identity-atlas/main/Web/assets/brand/identity-atlas-gallery-icon.svg'
            ReleaseNotes = 'Unpublished 1.1.0 development candidate. Corrected access semantics, coverage-aware comparisons, local report commands, optional checkpoints and delegated consent. See Docs/IMPROVEMENT-PLAN.md in the repository. Published stable release remains v1.0.0.'
        }
    }
}
