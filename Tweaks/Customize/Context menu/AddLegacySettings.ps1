# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\UltimateContextMenu\LegacySettings.reg "Legacy Control
# Panel Settings": a desktop submenu of Control Panel applets. Windows has no such key, so Revert deletes it.
$k = 'HKLM:\SOFTWARE\Classes\DesktopBackground\Shell\Personalization'
$item = { param($n, $icon, $verb, $cmd)
    @{ Path = "$k\shell\$n"; Name = 'Icon'; Type = 'String'; Value = $icon; Default = $null }
    @{ Path = "$k\shell\$n"; Name = 'MUIVerb'; Type = 'String'; Value = $verb; Default = $null }
    @{ Path = "$k\shell\$n\command"; Name = '(default)'; Type = 'String'; Value = $cmd; Default = $null }
}
@{
    Id          = 'context-add-legacy-settings'
    Name        = 'Add Legacy settings to the desktop menu'
    Section     = 'Customize'
    Category    = 'Context menu'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Right-clicking the desktop shows a Legacy settings submenu: the old Sound, Power Options, Mouse, System Properties and Desktop Icon Settings windows.'
    Registry    = @(
        @{ Path = $k; Name = 'Icon'; Type = 'String'; Value = 'shell32.dll,-137'; Default = $null }
        @{ Path = $k; Name = 'MUIVerb'; Type = 'String'; Value = 'Legacy settings'; Default = $null }
        @{ Path = $k; Name = 'Position'; Type = 'String'; Value = 'Bottom'; Default = $null }
        @{ Path = $k; Name = 'SubCommands'; Type = 'String'; Value = ''; Default = $null }
        & $item '001flyout' 'SndVol.exe,-101' 'Sound' 'rundll32.exe shell32.dll,Control_RunDLL mmsys.cpl,,0'
        & $item '002flyout' 'powercpl.dll,0' 'Power Options' 'rundll32.exe shell32.dll,Control_RunDLL powercfg.cpl'
        & $item '003flyout' 'main.cpl' 'Mouse Properties' 'rundll32.exe shell32.dll,Control_RunDLL main.cpl,,0'
        & $item '004flyout' 'SystemPropertiesAdvanced.exe' 'System Properties' 'SystemPropertiesAdvanced.exe'
        & $item '005flyout' 'desk.cpl' 'Desktop Icon Settings' 'rundll32.exe shell32.dll,Control_RunDLL desk.cpl,,0'
        @{ Path = $k; Value = 'Key'; Default = $null }
    )
}
