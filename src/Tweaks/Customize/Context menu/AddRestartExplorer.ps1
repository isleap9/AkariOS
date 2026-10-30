# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\UltimateContextMenu\AddRestartExplorer.reg "Restart
# Explorer": a desktop menu entry. Windows has no such key, so Revert deletes it.
$k = 'HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\RestartExplorer'
@{
    Id          = 'context-add-restart-explorer'
    Name        = 'Add Restart Explorer to the desktop menu'
    Section     = 'Customize'
    Category    = 'Context menu'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Right-clicking the desktop shows Restart Explorer, which restarts the taskbar and File Explorer when they hang.'
    Registry    = @(
        @{ Path = $k; Name = 'MUIVerb'; Type = 'String'; Value = 'Restart Explorer'; Default = $null }
        @{ Path = $k; Name = 'Icon'; Type = 'String'; Value = 'explorer.exe'; Default = $null }
        @{ Path = $k; Name = 'Position'; Type = 'String'; Value = 'Bottom'; Default = $null }
        @{ Path = $k; Name = 'SeparatorBefore'; Type = 'String'; Value = ''; Default = $null }
        @{ Path = "$k\command"; Name = '(default)'; Type = 'String'; Value = 'cmd.exe /c taskkill /f /im explorer.exe && start explorer.exe'; Default = $null }
        @{ Path = $k; Value = 'Key'; Default = $null }
    )
}
