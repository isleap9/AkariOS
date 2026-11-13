# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFTweaksConsumerFeatures".
@{
    Id          = 'privacy-consumer-features'
    Name        = 'No consumer features'
    Section     = 'Optimize'
    Category    = 'Privacy'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Group policy stops Windows installing suggested apps and games for new accounts. Full effect on Enterprise and Education; Pro honours part of it.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsConsumerFeatures'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
