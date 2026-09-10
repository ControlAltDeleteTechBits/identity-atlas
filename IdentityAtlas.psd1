@{
    RootModule        = 'IdentityAtlas.psm1'
    ModuleVersion     = '2.0.0'
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
            ReleaseNotes = 'Version 2.0.0: tenant administration home, object directory, application administration, group housekeeping, candidate administration responsibility and access verification. Read-only collection; local report. Scope and validation limits: https://github.com/ControlAltDeleteTechBits/identity-atlas/blob/main/Docs/RELEASE-NOTES-v2.0.0.md'
        }
    }
}
