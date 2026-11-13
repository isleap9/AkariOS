# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFToggleStandbyFix"
# (the machine policy: Windows doesn't read winutil's HKCU copy).
@{
    Id          = 'power-standby-no-network'
    Name        = 'No network during Modern Standby'
    Section     = 'Optimize'
    Category    = 'Power'
    Risk        = 'Caution'
    Guided      = $false
    Description = 'On PCs with Modern Standby (S0), the network goes off while the PC sleeps: less battery drain and fewer wake-ups, but no mail or downloads while asleep.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\f15576e8-98b7-4186-b944-eafa664402d9'; Name = 'ACSettingIndex'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\f15576e8-98b7-4186-b944-eafa664402d9'; Name = 'DCSettingIndex'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
