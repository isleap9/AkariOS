# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings.
@{
    Id          = 'performance-defrag-schedule-off'
    Name        = 'No scheduled drive optimization'
    Section     = 'Optimize'
    Category    = 'Performance'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Drives are optimized only when you run it yourself.'
    Registry    = @(
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Dfrg\TaskSettings'; Name = 'fAllVolumes'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Dfrg\TaskSettings'; Name = 'fDeadlineEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Dfrg\TaskSettings'; Name = 'fExclude'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Dfrg\TaskSettings'; Name = 'fTaskEnabled'; Type = 'DWord'; Value = 0; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Dfrg\TaskSettings'; Name = 'fUpgradeRestored'; Type = 'DWord'; Value = 1; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Dfrg\TaskSettings'; Name = 'TaskFrequency'; Type = 'DWord'; Value = 4; Default = $null }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Dfrg\TaskSettings'; Name = 'Volumes'; Type = 'String'; Value = ' '; Default = $null }
    )
    After       = {
        # the scheduled task is what actually runs
        Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -match 'ScheduledDefrag' } | ForEach-Object {
            if ($AkariMode -eq 'Apply') { Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath | Out-Null } else { Enable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath | Out-Null }
        }
    }
}
