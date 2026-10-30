# Ported from AkariOS-Ultimate (FR33THY Ultimate) 7 Hardware\2 Background Polling Rate Cap. A Choice over the raw mouse
# throttle (a Value block: two values). Windows has neither value (the cap is on at 125 Hz). No cap is the AkariOS
# pick (OneClick\reg.reg).
# 50 Hz: ZOICWARE's W11Tweaks "Set Background Mouse Throttle to 50hz" (https://github.com/zoicware/ZOICWARE, MIT).
@{
    Id          = 'input-background-polling-uncapped'
    Name        = 'No mouse polling cap in background windows'
    Section     = 'Hardware'
    Category    = 'Input'
    Kind        = 'Choice'
    Risk        = 'Safe'
    AkariOS     = $true
    Description = 'Windows 11 caps raw mouse input to 125 Hz for windows in the background; this lifts the cap (or lowers it to 50 Hz, ZOICWARE''s pick, for less CPU use).'
    Choices     = @(
        @{ Value = 'Uncapped'; Label = 'No cap' }
        @{ Value = '50Hz'; Label = 'Capped at 50 Hz (ZOICWARE)' }
        @{ Value = 'Default'; Label = 'Capped at 125 Hz' }
    )
    Recommended = 'Uncapped'
    Default     = 'Default'
    Value       = {
        $k = 'HKCU:\Control Panel\Mouse'
        $on = Get-AkariRegValue $k 'RawMouseThrottleEnabled'; $ms = Get-AkariRegValue $k 'RawMouseThrottleDuration'
        if ($null -eq $on -and $null -eq $ms) { 'Default' } elseif ($on -eq 0 -and $null -eq $ms) { 'Uncapped' } elseif ($on -eq 1 -and $ms -eq 20) { '50Hz' } else { $null }
    }
    Apply       = {
        $k = 'HKCU:\Control Panel\Mouse'
        switch ($AkariValue) {
            'Uncapped' { Set-Reg $k 'RawMouseThrottleEnabled' 0 'DWord'; Remove-Reg $k 'RawMouseThrottleDuration' }
            '50Hz' { Set-Reg $k 'RawMouseThrottleEnabled' 1 'DWord'; Set-Reg $k 'RawMouseThrottleDuration' 20 'DWord' }
            'Default' { Remove-Reg $k 'RawMouseThrottleEnabled'; Remove-Reg $k 'RawMouseThrottleDuration' }
            default { throw "unknown value $AkariValue" }
        }
    }
    Revert      = { Remove-Reg 'HKCU:\Control Panel\Mouse' 'RawMouseThrottleEnabled'; Remove-Reg 'HKCU:\Control Panel\Mouse' 'RawMouseThrottleDuration' }
}
