# Ported from AkariOS-Ultimate (FR33THY Ultimate) 5 Graphics\6 Amd Settings. Per AMD adapter key (and its UMD /
# power_v1 subkeys, only when the driver made them) plus AMD Software's own HKCU settings. AMD Software is opened and
# closed first so it has written its keys. Revert = the old script's Default.
@{
    Id          = 'graphics-amd-settings'
    Name        = 'AMD settings'
    Section     = 'Hardware'
    Category    = 'Graphics'
    Risk        = 'Caution'
    Requires    = 'AMD'
    Description = 'FR33THY''s AMD Software setup: Anti-Lag on, VSync off, performance texture filtering, tessellation off, Vari-Bright off; no overlay, hotkeys, ads, tray or update checks.'
    Detect      = {
        $cn = 'HKCU:\Software\AMD\CN'
        $w = Get-AkariRegValue $cn 'WizardProfile'; $a = Get-AkariRegValue $cn 'AllowWebContent'
        if ($w -eq 'PROFILE_CUSTOM' -and $a -eq 'false') { 'Optimized' } elseif ($null -eq $w -and $null -eq $a) { 'Default' } else { 'Custom' }
    }
    Apply       = {
        $rs = "$env:ProgramFiles\AMD\CNext\CNext\RadeonSoftware.exe"
        if (Test-Path -LiteralPath $rs) {
            Start-Process -FilePath $rs
            Start-Sleep -Seconds 30
            Stop-Process -Name RadeonSoftware -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
        }
        $cn = 'HKCU:\Software\AMD\CN'
        Set-Reg $cn 'AutoUpdate' 0
        Set-Reg 'HKCU:\Software\AMD\AIM' 'LaunchBugTool' 0
        Set-Reg 'HKCU:\Software\AMD\DVR' 'HotkeysDisabled' 1
        Set-Reg 'HKCU:\Software\AMD\DVR' 'ShowRSOverlay' 'false' 'String'
        foreach ($v in @(@('SystemTray', 'false'), @('RSXBrowserUnavailable', 'true'), @('AllowWebContent', 'false'), @('CN_Hide_Toast_Notification', 'true'),
                @('AnimationEffect', 'false'), @('WizardProfile', 'PROFILE_CUSTOM'))) { Set-Reg $cn $v[0] $v[1] 'String' }
        Set-Reg "$cn\CustomResolutions" 'EulaAccepted' 'true' 'String'
        Set-Reg "$cn\DisplayOverride" 'EulaAccepted' 'true' 'String'
        foreach ($g in @(Get-AkariGpus | Where-Object Vendor -eq 'AMD')) {
            Set-Reg $g.Path 'KMD_DeLagEnabled' 1
            Set-Reg $g.Path 'IsAutoDefault' ([byte[]](0, 0, 0, 0)) 'Binary'
            Set-Reg $g.Path 'IsComponentControl' ([byte[]](0x0f, 0, 0, 0)) 'Binary'
            if (Test-Path -LiteralPath (Resolve-AkariRegPath "$($g.Path)\UMD")) {
                Set-Reg "$($g.Path)\UMD" 'VSyncControl' ([byte[]](0x30, 0)) 'Binary'
                Set-Reg "$($g.Path)\UMD" 'TFQ' ([byte[]](0x32, 0)) 'Binary'
                Set-Reg "$($g.Path)\UMD" 'Tessellation' ([byte[]](0x31, 0)) 'Binary'
                Set-Reg "$($g.Path)\UMD" 'Tessellation_OPTION' ([byte[]](0x32, 0)) 'Binary'
            }
            if (Test-Path -LiteralPath (Resolve-AkariRegPath "$($g.Path)\power_v1")) { Set-Reg "$($g.Path)\power_v1" 'abmlevel' ([byte[]](0, 0, 0, 0)) 'Binary' }
        }
        # notifications already seen
        $n = Resolve-AkariRegPath "$cn\Notification"
        if (Test-Path -LiteralPath $n) { Remove-Item -LiteralPath $n -Recurse -Force }
        New-Item -Path $n -Force | Out-Null
        foreach ($k in 'FreeSync', 'OverlayNotification', 'VirtualSuperResolution') { Set-Reg "$cn\$k" 'AlreadyNotified' 1 }
    }
    Revert      = {
        $cn = 'HKCU:\Software\AMD\CN'
        Remove-Reg $cn 'AutoUpdate'
        Set-Reg 'HKCU:\Software\AMD\AIM' 'LaunchBugTool' 1
        Remove-Reg 'HKCU:\Software\AMD\DVR' 'HotkeysDisabled'
        Remove-Reg 'HKCU:\Software\AMD\DVR' 'ShowRSOverlay'
        foreach ($v in 'SystemTray', 'RSXBrowserUnavailable', 'AllowWebContent', 'CN_Hide_Toast_Notification', 'AnimationEffect', 'WizardProfile') { Remove-Reg $cn $v }
        foreach ($g in @(Get-AkariGpus | Where-Object Vendor -eq 'AMD')) {
            Set-Reg $g.Path 'KMD_DeLagEnabled' 0
            Set-Reg $g.Path 'IsAutoDefault' 1
            Set-Reg $g.Path 'IsComponentControl' ([byte[]](0, 0, 0, 0)) 'Binary'
            if (Test-Path -LiteralPath (Resolve-AkariRegPath "$($g.Path)\UMD")) {
                Set-Reg "$($g.Path)\UMD" 'VSyncControl' ([byte[]](0x31, 0, 0, 0)) 'Binary'
                Remove-Reg "$($g.Path)\UMD" 'TFQ'
                Set-Reg "$($g.Path)\UMD" 'Tessellation' ([byte[]](0x36, 0, 0x34, 0, 0, 0)) 'Binary'
                Set-Reg "$($g.Path)\UMD" 'Tessellation_OPTION' ([byte[]](0x30, 0, 0, 0)) 'Binary'
            }
            if (Test-Path -LiteralPath (Resolve-AkariRegPath "$($g.Path)\power_v1")) { Remove-Reg "$($g.Path)\power_v1" 'abmlevel' }
        }
        foreach ($k in 'CustomResolutions', 'DisplayOverride', 'Notification', 'FreeSync', 'OverlayNotification', 'VirtualSuperResolution') {
            $p = Resolve-AkariRegPath "$cn\$k"
            if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
        }
    }
}
