# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\5 Theme Black. Default = Windows' blue accent, not shown
# on Start and the taskbar.
@{
    Id          = 'theme-black-accent'
    Name        = 'Black accent color'
    Section     = 'Customize'
    Category    = 'Theme'
    Risk        = 'Safe'
    AkariOS     = $true
    Explorer    = $true
    Description = 'A near-black accent on Start, the taskbar and title bars instead of blue.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'; Name = 'ColorPrevalence'; Type = 'DWord'; Value = 1; Default = 0 }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'; Name = 'AccentPalette'; Type = 'Binary'
           Value = [byte[]](0x64, 0x64, 0x64, 0, 0x6b, 0x6b, 0x6b, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
           Default = [byte[]](0x99, 0xeb, 0xff, 0, 0x4c, 0xc2, 0xff, 0, 0, 0x91, 0xf8, 0, 0, 0x78, 0xd4, 0, 0, 0x67, 0xc0, 0, 0, 0x3e, 0x92, 0, 0, 0x1a, 0x68, 0, 0xf7, 0x63, 0x0c, 0) }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'; Name = 'StartColorMenu'; Type = 'DWord'; Value = 0; Default = 0xffc06700 }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'; Name = 'AccentColorMenu'; Type = 'DWord'; Value = 0; Default = 0xffd47800 }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\DWM'; Name = 'EnableWindowColorization'; Type = 'DWord'; Value = 1; Default = 0 }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\DWM'; Name = 'AccentColor'; Type = 'DWord'; Value = 0xff191919; Default = 0xffd47800 }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\DWM'; Name = 'ColorizationColor'; Type = 'DWord'; Value = 0xc4191919; Default = 0xc40078d4 }
        @{ Path = 'HKCU:\Software\Microsoft\Windows\DWM'; Name = 'ColorizationAfterglow'; Type = 'DWord'; Value = 0xc4191919; Default = 0xc40078d4 }
    )
}
