# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFToggleBatteryPercentage".
@{
    Id          = 'taskbar-battery-percentage'
    Name        = 'Battery percentage on the taskbar'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Risk        = 'Safe'
    Requires    = 'Win11', 'Laptop'
    Explorer    = $true
    Description = 'The battery icon shows the charge left as a percentage.'
    Registry    = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; Name = 'IsBatteryPercentageEnabled'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
