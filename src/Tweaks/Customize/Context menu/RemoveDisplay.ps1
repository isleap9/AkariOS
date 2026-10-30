# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Display (Desktop)": ZOICWARE deletes the
# key as TrustedInstaller (its owner); here a ProgrammaticAccessOnly value hides it instead, so Revert only deletes that
# value. Written as TrustedInstaller too.
@{
    Id          = 'context-remove-display'
    Name        = 'Remove Display settings from the desktop menu'
    Section     = 'Customize'
    Category    = 'Context menu'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Right-clicking the desktop no longer shows Display settings (Settings > System > Display still opens it).'
    Detect      = { Get-AkariRegistryState @(@{ Path = 'HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\Display'; Name = 'ProgrammaticAccessOnly'; Type = 'String'; Value = ''; Default = $null }) }
    Apply       = { Invoke-AkariRegistryTrusted @(@{ Path = 'HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\Display'; Name = 'ProgrammaticAccessOnly'; Type = 'String'; Value = ''; Default = $null }) Apply }
    Revert      = { Invoke-AkariRegistryTrusted @(@{ Path = 'HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\Display'; Name = 'ProgrammaticAccessOnly'; Type = 'String'; Value = ''; Default = $null }) Revert }
}
