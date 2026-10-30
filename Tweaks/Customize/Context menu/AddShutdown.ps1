# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\UltimateContextMenu\Shutdown.reg "Shutdown": a Shut Down
# submenu on the desktop's right-click menu. Windows has no such key, so Revert deletes it with everything in it.
$k = 'HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\ShutDown'
@{
    Id          = 'context-add-shutdown'
    Name        = 'Add Shut down and Restart to the desktop menu'
    Section     = 'Customize'
    Category    = 'Context menu'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Right-clicking the desktop shows a Shut Down submenu: shut down or restart, right away or with the usual warning.'
    Registry    = @(
        @{ Path = $k; Name = 'Position'; Type = 'String'; Value = 'Bottom'; Default = $null }
        @{ Path = $k; Name = 'MUIVerb'; Type = 'String'; Value = 'Shut Down'; Default = $null }
        @{ Path = $k; Name = 'SubCommands'; Type = 'String'; Value = ''; Default = $null }
        @{ Path = $k; Name = 'Icon'; Type = 'String'; Value = 'shell32.dll,-28'; Default = $null }
        @{ Path = "$k\shell\001ShutdownInstantly"; Name = 'Icon'; Type = 'String'; Value = 'shell32.dll,-28'; Default = $null }
        @{ Path = "$k\shell\001ShutdownInstantly"; Name = 'MUIVerb'; Type = 'String'; Value = 'Shut down instantly'; Default = $null }
        @{ Path = "$k\shell\001ShutdownInstantly\Command"; Name = '(default)'; Type = 'String'; Value = 'shutdown -s -f -t 0'; Default = $null }
        @{ Path = "$k\shell\002ShutdownWarning"; Name = 'MUIVerb'; Type = 'String'; Value = 'Shut down with warning'; Default = $null }
        @{ Path = "$k\shell\002ShutdownWarning"; Name = 'Icon'; Type = 'String'; Value = 'shell32.dll,-28'; Default = $null }
        @{ Path = "$k\shell\002ShutdownWarning\Command"; Name = '(default)'; Type = 'String'; Value = 'shutdown -s'; Default = $null }
        @{ Path = "$k\shell\003RestartInstantly"; Name = 'MUIVerb'; Type = 'String'; Value = 'Restart instantly'; Default = $null }
        @{ Path = "$k\shell\003RestartInstantly"; Name = 'Icon'; Type = 'String'; Value = 'shell32.dll,-16739'; Default = $null }
        @{ Path = "$k\shell\003RestartInstantly"; Name = 'CommandFlags'; Type = 'DWord'; Value = 0x20; Default = $null }
        @{ Path = "$k\shell\003RestartInstantly\Command"; Name = '(default)'; Type = 'String'; Value = 'shutdown -r -f -t 0'; Default = $null }
        @{ Path = "$k\shell\004RestartWarning"; Name = 'Icon'; Type = 'String'; Value = 'shell32.dll,-16739'; Default = $null }
        @{ Path = "$k\shell\004RestartWarning"; Name = 'MUIVerb'; Type = 'String'; Value = 'Restart with warning'; Default = $null }
        @{ Path = "$k\shell\004RestartWarning\Command"; Name = '(default)'; Type = 'String'; Value = 'shutdown -r'; Default = $null }
        @{ Path = $k; Value = 'Key'; Default = $null }
    )
}
