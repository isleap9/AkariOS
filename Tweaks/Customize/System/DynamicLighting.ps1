# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'system-no-dynamic-lighting'
    Name        = 'Dynamic Lighting off'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    AkariOS     = $true
    Requires    = 'Win11'
    Description = 'Windows leaves RGB lighting to your own apps.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Lighting'; Name = 'AmbientLightingEnabled'; Type = 'DWord'; Value = 0; Default = 1 }
        @{ Path = 'HKCU:\Software\Microsoft\Lighting'; Name = 'ControlledByForegroundApp'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKCU:\Software\Microsoft\Lighting'; Name = 'UseSystemAccentColor'; Type = 'DWord'; Value = 0; Default = 1 }
    )
}
