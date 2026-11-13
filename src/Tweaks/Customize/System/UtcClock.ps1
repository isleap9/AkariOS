# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFTweaksUTC".
@{
    Id          = 'system-utc-clock'
    Name        = 'Hardware clock in UTC'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Advanced'
    Guided      = $false
    Reboot      = $true
    Description = 'Windows reads the PC''s hardware clock as UTC, as Linux does, so the time stays right when you dual boot. Only for dual boot.'
    Registry    = @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation'; Name = 'RealTimeIsUniversal'; Type = 'QWord'; Value = 1; Default = $null }
    )
}
