# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable co installers".
@{
    Id          = 'system-no-coinstallers'
    Name        = 'No vendor installers with new devices'
    Section     = 'Advanced'
    Category    = 'System'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Plugging in a mouse, headset or controller installs only its driver, not the vendor''s companion app (Razer Synapse, Logitech and the like).'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Installer'; Name = 'DisableCoInstallers'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
