# From ZOICWARE (https://github.com/zoicware/ZOICWARE, MIT) src\zFunctions.psm1 import-powerplan "Power Mode High
# Performance" (powercfg /OverlaySetActive OVERLAY_SCHEME_MAX); Revert = "Power Mode Balanced" (OVERLAY_SCHEME_NONE).
# powercfg can set the overlay but not read it: Detect reads the values Windows keeps it in, which the blocks also
# write. powercfg only through Invoke-AkariPowerCfg (Core\System.ps1).
@{
    Id          = 'power-mode-best-performance'
    Name        = 'Power mode: best performance'
    Section     = 'Optimize'
    Category    = 'Power'
    Risk        = 'Safe'
    Guided      = $false
    Requires    = 'Win11'
    Description = 'Sets Settings > Power > Power mode to "Best performance". It only changes something while the Balanced power plan is active: with the Ultimate Performance plan, the plan already decides.'
    Detect      = {
        $v = Get-AkariRegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes' 'ActiveOverlayAcPowerScheme'
        if ($v -eq 'ded574b5-45a0-4f42-8737-46345c09c238') { 'Optimized' }
        elseif ($null -eq $v -or $v -eq '00000000-0000-0000-0000-000000000000') { 'Default' }
        else { 'Custom' }
    }
    Apply       = {
        [void](Invoke-AkariPowerCfg '/overlaysetactive' 'OVERLAY_SCHEME_MAX')
        foreach ($n in 'ActiveOverlayAcPowerScheme', 'ActiveOverlayDcPowerScheme') {
            Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes' $n 'ded574b5-45a0-4f42-8737-46345c09c238' 'String'
        }
    }
    Revert      = {
        [void](Invoke-AkariPowerCfg '/overlaysetactive' 'OVERLAY_SCHEME_NONE')
        foreach ($n in 'ActiveOverlayAcPowerScheme', 'ActiveOverlayDcPowerScheme') {
            Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes' $n '00000000-0000-0000-0000-000000000000' 'String'
        }
    }
}
