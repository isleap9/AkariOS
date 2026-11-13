# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFToggleS3Sleep".
@{
    Id          = 'power-s3-sleep'
    Name        = 'Classic S3 sleep instead of Modern Standby'
    Section     = 'Optimize'
    Category    = 'Power'
    Risk        = 'Advanced'
    Guided      = $false
    Reboot      = $true
    Description = 'Turns Modern Standby off so the PC sleeps the classic way (S3): fully asleep, no wake-ups in a bag. Without S3 in the firmware the PC can''t sleep at all; Revert brings Modern Standby back.'
    Registry    = @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power'; Name = 'PlatformAoAcOverride'; Type = 'DWord'; Value = 0; Default = $null }
    )
}
