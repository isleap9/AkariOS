# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFTweaksDisableWarningForUnsignedRdp".
@{
    Id          = 'security-rdp-unsigned-warning'
    Name        = 'No warning on unsigned Remote Desktop files'
    Section     = 'Advanced'
    Category    = 'Security'
    Risk        = 'Caution'
    Guided      = $false
    Description = 'Remote Desktop opens .rdp files without the unsigned-publisher and redirection warnings. Only for .rdp files you trust.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services\Client'; Name = 'RedirectionWarningDialogVersion'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKCU:\SOFTWARE\Microsoft\Terminal Server Client'; Name = 'RdpLaunchConsentAccepted'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
