# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\1 Start Menu Taskbar. Windows 10 has one switch;
# Windows 11 keeps one key per tray icon (Control Panel\NotifyIconSettings), so this sets every icon.
@{
    Id          = 'taskbar-show-all-tray-icons'
    Name        = 'Show all tray icons'
    Section     = 'Customize'
    Category    = 'Taskbar'
    Risk        = 'Safe'
    AkariOS     = $true
    Explorer    = $true
    Description = 'Every notification area icon sits on the taskbar instead of in the overflow menu. On Windows 11 this covers the icons Windows knows so far.'
    Detect      = {
        if ((Get-AkariOSBuild) -lt 22000) {
            $v = Get-AkariRegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' 'EnableAutoTray'
            if ($v -eq 0) { return 'Optimized' } elseif ($null -eq $v) { return 'Default' } else { return 'Custom' }
        }
        $keys = @(Get-ChildItem (Resolve-AkariRegPath 'HKCU:\Control Panel\NotifyIconSettings') -ErrorAction SilentlyContinue)
        if (-not $keys.Count) { return 'Unknown' }
        $on = @($keys | Where-Object { (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).IsPromoted -eq 1 }).Count
        if ($on -eq $keys.Count) { 'Optimized' } elseif ($on -eq 0) { 'Default' } else { 'Custom' }
    }
    Apply       = {
        if ((Get-AkariOSBuild) -lt 22000) { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' 'EnableAutoTray' 0; return }
        foreach ($k in @(Get-ChildItem (Resolve-AkariRegPath 'HKCU:\Control Panel\NotifyIconSettings') -ErrorAction SilentlyContinue)) {
            Set-ItemProperty -Path $k.PSPath -Name 'IsPromoted' -Value 1 -Type DWord -Force
        }
    }
    # Windows' own default: icons wait in the overflow menu until you drag them out
    Revert      = {
        if ((Get-AkariOSBuild) -lt 22000) { Remove-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer' 'EnableAutoTray'; return }
        foreach ($k in @(Get-ChildItem (Resolve-AkariRegPath 'HKCU:\Control Panel\NotifyIconSettings') -ErrorAction SilentlyContinue)) {
            Set-ItemProperty -Path $k.PSPath -Name 'IsPromoted' -Value 0 -Type DWord -Force
        }
    }
}
