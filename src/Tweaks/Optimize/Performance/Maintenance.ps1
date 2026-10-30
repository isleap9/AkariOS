# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'performance-maintenance-off'
    Name        = 'Automatic maintenance off'
    Section     = 'Optimize'
    Category    = 'Performance'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'No nightly maintenance (scans, defrag, diagnostics) waking the PC or running while you play.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance'; Name = 'MaintenanceDisabled'; Type = 'DWord'; Value = 1; Default = $null }
    )
}
