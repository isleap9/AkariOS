# Ported from AkariOS-Ultimate (FR33THY Ultimate) 3 Setup\12 Updates Pause (One-click does it in steptwo.ps1).
# Dates, so blocks instead of Registry rows. Revert = no pause (the Resume button in Windows Update).
@{
    Id          = 'update-pause-one-year'
    Name        = 'Pause Windows updates for a year'
    Section     = 'Optimize'
    Category    = 'Update'
    Risk        = 'Caution'
    AkariOS     = $true
    Description = 'Pauses feature and quality updates for 365 days from today. Security updates wait too.'
    Detect      = {
        $end = Get-AkariRegValue 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings' 'PauseUpdatesExpiryTime'
        if (-not $end) { return 'Default' }
        try { if ([datetime]::Parse($end).ToUniversalTime() -gt (Get-Date).ToUniversalTime()) { 'Optimized' } else { 'Default' } } catch { 'Custom' }
    }
    Apply       = {
        $k = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
        $now = (Get-Date).ToUniversalTime()
        $start = $now.ToString('yyyy-MM-ddTHH:mm:ssZ'); $end = $now.AddDays(365).ToString('yyyy-MM-ddTHH:mm:ssZ')
        foreach ($n in 'PauseUpdatesExpiryTime', 'PauseFeatureUpdatesEndTime', 'PauseQualityUpdatesEndTime') { Set-Reg $k $n $end 'String' }
        foreach ($n in 'PauseUpdatesStartTime', 'PauseFeatureUpdatesStartTime', 'PauseQualityUpdatesStartTime') { Set-Reg $k $n $start 'String' }
    }
    Revert      = {
        $k = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
        foreach ($n in 'PauseUpdatesExpiryTime', 'PauseFeatureUpdatesEndTime', 'PauseQualityUpdatesEndTime', 'PauseUpdatesStartTime', 'PauseFeatureUpdatesStartTime', 'PauseQualityUpdatesStartTime') { Remove-Reg $k $n }
    }
}
