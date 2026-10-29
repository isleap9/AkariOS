# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\RegTweaks.txt "Disable sleep study".
@{
    Id          = 'power-sleep-study-off'
    Name        = 'No sleep study logging'
    Section     = 'Optimize'
    Category    = 'Power'
    Risk        = 'Safe'
    Guided      = $false
    Reboot      = $true
    Description = 'Windows stops recording what keeps the PC awake during modern standby (the sleep study report).'
    Registry    = @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'; Name = 'SleepStudyDisabled'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
