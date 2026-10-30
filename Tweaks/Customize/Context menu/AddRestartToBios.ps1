# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\UltimateContextMenu\AddRestarttoBIOS.reg "Restart to
# BIOS": a desktop menu entry. Akari only writes the command; it never runs it. Revert deletes the key.
$k = 'HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\RestartToBIOS'
@{
    Id          = 'context-add-restart-to-bios'
    Name        = 'Add Restart to BIOS to the desktop menu'
    Section     = 'Customize'
    Category    = 'Context menu'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Right-clicking the desktop shows Restart to BIOS, which restarts straight into the UEFI firmware settings.'
    Registry    = @(
        @{ Path = $k; Name = 'MUIVerb'; Type = 'String'; Value = 'Restart to BIOS'; Default = $null }
        @{ Path = $k; Name = 'Icon'; Type = 'String'; Value = 'shell32.dll,27'; Default = $null }
        @{ Path = $k; Name = 'Position'; Type = 'String'; Value = 'Bottom'; Default = $null }
        @{ Path = $k; Name = 'SeparatorBefore'; Type = 'String'; Value = ''; Default = $null }
        @{ Path = "$k\command"; Name = '(default)'; Type = 'String'; Value = 'cmd.exe /c shutdown /r /fw /t 0 & shutdown /r /fw /t 0'; Default = $null }
        @{ Path = $k; Value = 'Key'; Default = $null }
    )
}
