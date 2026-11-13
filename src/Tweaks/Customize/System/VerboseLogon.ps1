# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFToggleVerboseLogon".
@{
    Id          = 'system-verbose-logon'
    Name        = 'Detailed status at sign-in and shutdown'
    Section     = 'Customize'
    Category    = 'System'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Signing in, out and shutting down say what Windows is doing (services, group policy) instead of "Please wait".'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'; Name = 'VerboseStatus'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
