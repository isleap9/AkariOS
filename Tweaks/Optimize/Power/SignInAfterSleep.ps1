# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\22 Control Panel Settings (One-click does the same): the
# active plan's "require sign-in on wake" (console lock), AC and DC. Revert = on, as Windows ships it.
@{
    Id          = 'power-no-sign-in-after-sleep'
    Name        = 'No sign-in after sleep'
    Section     = 'Optimize'
    Category    = 'Power'
    Risk        = 'Caution'
    AkariOS     = $true
    Description = 'Waking the PC from sleep or the screen turning back on doesn''t ask for your password (current power plan).'
    # the two indexes powercfg prints for the setting (AC, DC), whatever the language; /qh, as Windows hides it
    Detect      = {
        $v = @(Invoke-AkariPowerCfg '/qh' 'scheme_current' 'sub_none' 'consolelock' | ForEach-Object { if ($_ -match ':\s*0x([0-9a-f]{8})\s*$') { [Convert]::ToInt32($Matches[1], 16) } } | Select-Object -Last 2)
        if ($v.Count -lt 2) { 'Unknown' } elseif (-not ($v -ne 0)) { 'Optimized' } elseif (-not ($v -ne 1)) { 'Default' } else { 'Custom' }
    }
    Apply       = {
        [void](Invoke-AkariPowerCfg '/setacvalueindex' 'scheme_current' 'sub_none' 'consolelock' 0)
        [void](Invoke-AkariPowerCfg '/setdcvalueindex' 'scheme_current' 'sub_none' 'consolelock' 0)
    }
    Revert      = {
        [void](Invoke-AkariPowerCfg '/setacvalueindex' 'scheme_current' 'sub_none' 'consolelock' 1)
        [void](Invoke-AkariPowerCfg '/setdcvalueindex' 'scheme_current' 'sub_none' 'consolelock' 1)
    }
}
