# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 "Remove Quick Settings Tiles (24H2+)":
# only its SimplifyQuickSettings policy (its UserLayoutPaginated rewrite and the logon task that repeats it are not
# ported: Windows writes that value, so it has no Default). Revert deletes the policy.
@{
    Id          = 'taskbar-simple-quick-settings'
    Name        = 'Simple Quick Settings'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Risk        = 'Safe'
    Requires    = 'Win11'
    Guided      = $false
    Explorer    = $true
    Description = 'The Quick Settings panel (network, volume, battery in the taskbar) shows only the basic tiles and can''t be edited. Windows 11 24H2 and later.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'; Name = 'SimplifyQuickSettings'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
