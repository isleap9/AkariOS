# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable network throttling".
@{
    Id          = 'network-no-throttling'
    Name        = 'No network throttling during media playback'
    Section     = 'Optimize'
    Category    = 'Network'
    Risk        = 'Caution'
    Guided      = $false
    Reboot      = $true
    Description = 'Windows stops limiting other network traffic while audio or video plays. Mostly matters on older or busy systems.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'; Name = 'NetworkThrottlingIndex'; Type = 'DWord'; Value = 0xffffffff; Default = 10 }
    )
}
