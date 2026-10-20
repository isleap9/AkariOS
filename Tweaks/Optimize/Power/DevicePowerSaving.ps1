# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\25 Device Manager Power Savings & Wake (One-click does the
# same): every ACPI, HID, PCI and USB device on this PC. The old script also wrote the misspelt
# "SeleactiveSuspendEnabled" on ACPI devices; Revert removes it too. Devices plugged in later keep Windows' settings.
@{
    Id          = 'power-device-power-saving-off'
    Name        = 'Device power saving and wake off'
    Section     = 'Optimize'
    Category    = 'Power'
    Risk        = 'Caution'
    AkariOS     = $true
    Reboot      = $true
    Description = 'Devices (mouse, keyboard, USB, PCI) never power down to save energy and can''t wake the PC. Wake by the power button only.'
    Detect      = {
        $keys = @(foreach ($b in 'ACPI', 'HID', 'PCI', 'USB') { Get-ChildItem (Resolve-AkariRegPath "HKLM:\SYSTEM\ControlSet001\Enum\$b") -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq 'Device Parameters' } })
        if (-not $keys.Count) { return 'Unknown' }
        $off = @($keys | Where-Object { (Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue).WaitWakeEnabled -eq 0 }).Count
        if ($off -eq $keys.Count) { 'Optimized' } elseif ($off -eq 0) { 'Default' } else { 'Custom' }
    }
    Apply       = {
        foreach ($b in 'ACPI', 'HID', 'PCI', 'USB') {
            foreach ($k in @(Get-ChildItem (Resolve-AkariRegPath "HKLM:\SYSTEM\ControlSet001\Enum\$b") -Recurse -ErrorAction SilentlyContinue)) {
                # a device whose key refuses the change (permissions) is skipped, as the script's reg add did
                if ($k.PSChildName -eq 'Device Parameters') {
                    New-ItemProperty -LiteralPath $k.PSPath -Name 'EnhancedPowerManagementEnabled' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
                    New-ItemProperty -LiteralPath $k.PSPath -Name 'SelectiveSuspendEnabled' -Value ([byte[]](0)) -PropertyType Binary -Force -ErrorAction SilentlyContinue | Out-Null
                    New-ItemProperty -LiteralPath $k.PSPath -Name 'SelectiveSuspendOn' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
                    New-ItemProperty -LiteralPath $k.PSPath -Name 'WaitWakeEnabled' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
                }
                elseif ($k.PSChildName -eq 'WDF') {
                    New-ItemProperty -LiteralPath $k.PSPath -Name 'IdleInWorkingState' -Value 0 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
                }
            }
        }
    }
    Revert      = {
        foreach ($b in 'ACPI', 'HID', 'PCI', 'USB') {
            foreach ($k in @(Get-ChildItem (Resolve-AkariRegPath "HKLM:\SYSTEM\ControlSet001\Enum\$b") -Recurse -ErrorAction SilentlyContinue)) {
                $names = if ($k.PSChildName -eq 'Device Parameters') { 'EnhancedPowerManagementEnabled', 'SelectiveSuspendEnabled', 'SeleactiveSuspendEnabled', 'SelectiveSuspendOn', 'WaitWakeEnabled' }
                         elseif ($k.PSChildName -eq 'WDF') { 'IdleInWorkingState' } else { @() }
                foreach ($n in $names) { Remove-ItemProperty -LiteralPath $k.PSPath -Name $n -ErrorAction SilentlyContinue }
            }
        }
    }
}
