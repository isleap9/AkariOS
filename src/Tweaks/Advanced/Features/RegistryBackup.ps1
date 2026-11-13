# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/feature.json
# "WPFFeatureRegBackup". Windows' own RegIdleBackup runs only in automatic maintenance, which AkariOS turns off: a daily
# task of Akari's runs it. Revert removes both values (Windows sets neither) and the task.
@{
    Id          = 'features-registry-backup'
    Name        = 'Daily registry backup'
    Section     = 'Advanced'
    Category    = 'Features'
    Risk        = 'Safe'
    Guided      = $false
    Description = 'Backs up the registry every day at 00:30 into Windows\System32\config\RegBack (two copies kept), as Windows did before 1803. Useful when Windows won''t start.'
    Detect      = {
        $k = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Configuration Manager'
        $v = @((Get-AkariRegValue $k 'EnablePeriodicBackup'), (Get-AkariRegValue $k 'BackupCount'))
        $task = try { [bool](Get-AkariTasks '\AkariOS\' 'RegistryBackup') } catch { $false }
        if ($v[0] -eq 1 -and $v[1] -eq 2 -and $task) { 'Optimized' } elseif ($null -eq $v[0] -and $null -eq $v[1] -and -not $task) { 'Default' } else { 'Custom' }
    }
    Apply       = {
        $k = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Configuration Manager'
        Set-Reg $k 'EnablePeriodicBackup' 1 'DWord'
        Set-Reg $k 'BackupCount' 2 'DWord'
        Register-AkariDailyTask '\AkariOS\' 'RegistryBackup' 'schtasks.exe' '/run /i /tn "\Microsoft\Windows\Registry\RegIdleBackup"' '00:30' 'Backs up the registry every day (AkariOS)'
    }
    Revert      = {
        $k = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Configuration Manager'
        Remove-Reg $k 'EnablePeriodicBackup'
        Remove-Reg $k 'BackupCount'
        Unregister-AkariTask '\AkariOS\' 'RegistryBackup'
    }
}
