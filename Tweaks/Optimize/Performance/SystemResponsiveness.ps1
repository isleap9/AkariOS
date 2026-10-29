# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Set system responsiveness to 10".
@{
    Id          = 'performance-system-responsiveness'
    Name        = 'Give games more CPU time over background tasks'
    Section     = 'Optimize'
    Category    = 'Performance'
    Risk        = 'Caution'
    Guided      = $false
    Reboot      = $true
    Description = 'The multimedia scheduler keeps 10% of the CPU for background work instead of 20%, leaving more for games and audio.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'; Name = 'SystemResponsiveness'; Type = 'DWord'; Value = 10; Default = 20 }
    )
}
