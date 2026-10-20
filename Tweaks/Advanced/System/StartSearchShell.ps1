# Ported from AkariOS-Ultimate (FR33THY Ultimate) 8 Advanced\18 Start Search Shell Mobsync. The app folders and
# mobsync.exe are moved into %SystemRoot% (not deleted), so Revert moves them back. The taskbar search box is
# taskbar-hide-search's value; the old script also set it.
@{
    Id          = 'system-start-search-shell-off'
    Name        = 'Remove Start menu, Search and Shell hosts'
    Section     = 'Advanced'
    Category    = 'System'
    Risk        = 'Advanced'
    Reboot      = $true
    Explorer    = $true
    Description = 'Stops the Start menu, Windows Search, Action Center and Sync Center from ever running. The Start button stops working; use Open-Shell or similar.'
    Detect      = {
        $names = 'Microsoft.Windows.Search_cw5n1h2txyewy', 'ShellExperienceHost_cw5n1h2txyewy', 'Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy'
        $moved = @($names | Where-Object { Test-Path -LiteralPath "$env:SystemRoot\$_" }).Count + [int](Test-Path -LiteralPath "$env:SystemRoot\mobsync.exe")
        $inPlace = @($names | Where-Object { Test-Path -LiteralPath "$env:SystemRoot\SystemApps\$_" }).Count + [int](Test-Path -LiteralPath "$env:SystemRoot\System32\mobsync.exe")
        if ($moved -and -not $inPlace) { 'Optimized' } elseif ($inPlace -and -not $moved) { 'Default' } else { 'Custom' }
    }
    Apply       = {
        $stop = 'AppActions', 'Copilot', 'CrossDeviceResume', 'FESearchHost', 'MiniSearchHost', 'RuntimeBroker', 'ScreenClippingHost',
            'Search', 'SearchApp', 'SearchHost', 'ShellExperienceHost', 'StartMenuExperienceHost', 'StoreDesktopExtension', 'TextInputHost',
            'WebExperienceHostApp', 'WidgetService', 'Widgets', 'backgroundTaskHost', 'explorer', 'mobsync', 'smartscreen'
        $moves = @(
            ,@("$env:SystemRoot\SystemApps\Microsoft.Windows.Search_cw5n1h2txyewy", "$env:SystemRoot\Microsoft.Windows.Search_cw5n1h2txyewy")
            ,@("$env:SystemRoot\SystemApps\ShellExperienceHost_cw5n1h2txyewy", "$env:SystemRoot\ShellExperienceHost_cw5n1h2txyewy")
            ,@("$env:SystemRoot\SystemApps\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy", "$env:SystemRoot\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy")
            ,@("$env:SystemRoot\System32\mobsync.exe", "$env:SystemRoot\mobsync.exe")
        )
        foreach ($m in $moves) { Grant-AkariOwnership $m[0] }
        # the hosts start again on their own: stop them right before each move, a few tries
        foreach ($m in $moves) {
            for ($try = 0; $try -lt 5 -and (Test-Path -LiteralPath $m[0]) -and -not (Test-Path -LiteralPath $m[1]); $try++) {
                $stop | ForEach-Object { Stop-Process -Name $_ -Force -ErrorAction SilentlyContinue }
                Move-Item -LiteralPath $m[0] -Destination $m[1] -Force -ErrorAction SilentlyContinue
                if (Test-Path -LiteralPath $m[0]) { Start-Sleep -Milliseconds 500 }
            }
            if (Test-Path -LiteralPath $m[0]) { throw "could not move $($m[0]) (in use)" }
        }
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Search\DisableSearch' 'value' 1
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableSearch' 1
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\WSearch' 'Start' 4
        Stop-Service -Name WSearch -Force -ErrorAction SilentlyContinue
    }
    Revert      = {
        $moves = @(
            ,@("$env:SystemRoot\Microsoft.Windows.Search_cw5n1h2txyewy", "$env:SystemRoot\SystemApps\Microsoft.Windows.Search_cw5n1h2txyewy")
            ,@("$env:SystemRoot\ShellExperienceHost_cw5n1h2txyewy", "$env:SystemRoot\SystemApps\ShellExperienceHost_cw5n1h2txyewy")
            ,@("$env:SystemRoot\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy", "$env:SystemRoot\SystemApps\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy")
            ,@("$env:SystemRoot\mobsync.exe", "$env:SystemRoot\System32\mobsync.exe")
        )
        foreach ($m in $moves) {
            if (-not (Test-Path -LiteralPath $m[0]) -or (Test-Path -LiteralPath $m[1])) { continue }
            Grant-AkariOwnership $m[0]
            Move-Item -LiteralPath $m[0] -Destination $m[1] -Force
        }
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Search\DisableSearch' 'value' 0
        Remove-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableSearch'
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\WSearch' 'Start' 2
        Start-Service -Name WSearch -ErrorAction SilentlyContinue
    }
}
