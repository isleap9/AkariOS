# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'gaming-hags'
    Name        = 'Hardware-accelerated GPU scheduling'
    Section     = 'Optimize'
    Category    = 'Gaming'
    Risk        = 'Safe'
    AkariOS     = $true
    Reboot      = $true
    Description = 'The graphics card schedules its own work (lower latency on recent GPUs and drivers).'
    Registry    = @(
        @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'; Name = 'HwSchMode'; Type = 'DWord'; Value = 2; Default = $null }
    )
}
