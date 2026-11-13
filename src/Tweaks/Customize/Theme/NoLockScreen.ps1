# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFToggleDisableLockscreen".
@{
    Id          = 'theme-no-lock-screen'
    Name        = 'No lock screen'
    Section     = 'Customize'
    Category    = 'Theme'
    Risk        = 'Safe'
    Requires    = 'Pro'
    Description = 'Group policy skips the lock screen: the PC goes straight to the sign-in screen. Home ignores the policy.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization'; Name = 'NoLockScreen'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
