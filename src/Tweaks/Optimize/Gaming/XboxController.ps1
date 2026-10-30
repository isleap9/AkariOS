# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\19 Gamebar and 22 Control Panel Settings: the controller
# guide button and the ms-gamebar links. The links point at systray.exe (does nothing) so a controller doesn't pop
# "get an app for ms-gamebar" once the Xbox apps are removed. The old .reg wrote "(Default)" as a value name; this
# sets each key's real default value, as intended. Revert = the links as Windows ships them.
$c = 'HKLM:\SOFTWARE\Classes'
@{
    Id          = 'gaming-xbox-controller-no-game-bar'
    Name        = 'Controller Xbox button doesn''t open Game Bar'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'The Xbox button and View + Menu no longer open Game Bar, and no "get an app" pop-up appears when the Xbox apps are removed.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\GameBar'; Name = 'UseNexusForGameBarEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\GameBar'; Name = 'GamepadNexusChordEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        foreach ($p in 'ms-gamebar', 'ms-gamingoverlay') {
            @{ Path = "$c\$p"; Name = 'NoOpenWith'; Type = 'String'; Value = ''; Default = $null }
            @{ Path = "$c\$p\shell\open\command"; Name = '(default)'; Type = 'String'; Value = '%SystemRoot%\System32\systray.exe'; Default = $null }
            @{ Path = "$c\$p\shell\open\command"; Value = 'Key'; Default = $null }
        }
        # ms-gamebarservices is not a Windows link: Revert deletes it
        @{ Path = "$c\ms-gamebarservices"; Name = '(default)'; Type = 'String'; Value = 'URL:ms-gamebarservices'; Default = $null }
        @{ Path = "$c\ms-gamebarservices"; Name = 'URL Protocol'; Type = 'String'; Value = ''; Default = $null }
        @{ Path = "$c\ms-gamebarservices"; Name = 'NoOpenWith'; Type = 'String'; Value = ''; Default = $null }
        @{ Path = "$c\ms-gamebarservices\shell\open\command"; Name = '(default)'; Type = 'String'; Value = '%SystemRoot%\System32\systray.exe'; Default = $null }
        @{ Path = "$c\ms-gamebarservices"; Value = 'Key'; Default = $null }
    )
}
