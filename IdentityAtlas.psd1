@{
    RootModule        = 'IdentityAtlas.psm1'
    ModuleVersion     = '0.14.0'
    GUID              = 'f0ce5f0e-34dc-4c59-9c12-3e35b581e955'
    Author            = 'Mark Oldham'
    CompanyName       = 'Control Alt Delete Tech Bits'
    Copyright         = '(c) 2026 Control Alt Delete Tech Bits. MIT licensed.'
    Description       = 'A local visual explorer for Microsoft Entra objects, relationships and access paths.'
    PowerShellVersion = '7.0'
    FunctionsToExport = @(
        'Connect-IdentityAtlas'
        'Invoke-IdentityAtlas'
        'Export-IdentityAtlas'
        'Compare-IdentityAtlas'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags       = @('MicrosoftEntra', 'MicrosoftGraph', 'Identity', 'Visualisation')
            LicenseUri = 'https://opensource.org/license/mit'
            ProjectUri = 'https://github.com/ControlAltDeleteTechBits/identity-atlas'
            Prerelease = 'preview1'
        }
    }
}
