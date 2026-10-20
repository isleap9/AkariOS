# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\29 Power Plan (One-click does the same). powercfg
# /hibernate also deletes or recreates hiberfil.sys, so this is not just the registry values.
@{
    Id          = 'power-hibernate-off'
    Name        = 'Hibernate off'
    Section     = 'Optimize'
    Category    = 'Power'
    Risk        = 'Safe'
    AkariOS     = $true
    Reboot      = $true
    Description = 'No hibernation: frees the disk space of hiberfil.sys (the size of your RAM). Also turns off fast startup.'
    Detect      = {
        $v = Get-AkariRegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled'
        if ($v -eq 0) { 'Optimized' } elseif ($null -eq $v -or $v -eq 1) { 'Default' } else { 'Custom' }
    }
    Apply       = {
        [void](Invoke-AkariPowerCfg '/hibernate' 'off')
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled' 0
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabledDefault' 0
    }
    Revert      = {
        [void](Invoke-AkariPowerCfg '/hibernate' 'on')
        Remove-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled'
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabledDefault' 1
    }
}
