# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\26 Network Adapter Power Savings & Wake (One-click does
# the same): every network adapter on this PC (its driver settings under the network class key).
@{
    Id          = 'power-network-adapter-power-saving-off'
    Name        = 'Network adapter power saving and wake off'
    Section     = 'Optimize'
    Category    = 'Power'
    Risk        = 'Safe'
    AkariOS     = $true
    Reboot      = $true
    Description = 'Network adapters never power down, no Energy-Efficient Ethernet or green modes, no Wake-on-LAN.'
    Detect      = {
        $keys = @(Get-ChildItem -LiteralPath (Resolve-AkariRegPath 'HKLM:\SYSTEM\ControlSet001\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}') -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' })
        if (-not $keys.Count) { return 'Unknown' }
        $off = @($keys | Where-Object { (Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue).PnPCapabilities -eq 24 }).Count
        if ($off -eq $keys.Count) { 'Optimized' } elseif ($off -eq 0) { 'Default' } else { 'Custom' }
    }
    Apply       = {
        $text = 'AdvancedEEE', '*EEE', 'EEELinkAdvertisement', 'SipsEnabled', 'ULPMode', 'GigaLite', 'EnableGreenEthernet', 'PowerSavingMode',
                'S5WakeOnLan', '*WakeOnMagicPacket', '*ModernStandbyWoLMagicPacket', '*WakeOnPattern', 'WakeOnLink'
        foreach ($k in @(Get-ChildItem -LiteralPath (Resolve-AkariRegPath 'HKLM:\SYSTEM\ControlSet001\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}') -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' })) {
            New-ItemProperty -LiteralPath $k.PSPath -Name 'PnPCapabilities' -Value 24 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
            foreach ($n in $text) { New-ItemProperty -LiteralPath $k.PSPath -Name $n -Value '0' -PropertyType String -Force -ErrorAction SilentlyContinue | Out-Null }
        }
    }
    Revert      = {
        $names = 'PnPCapabilities', 'AdvancedEEE', '*EEE', 'EEELinkAdvertisement', 'SipsEnabled', 'ULPMode', 'GigaLite', 'EnableGreenEthernet', 'PowerSavingMode',
                 'S5WakeOnLan', '*WakeOnMagicPacket', '*ModernStandbyWoLMagicPacket', '*WakeOnPattern', 'WakeOnLink'
        foreach ($k in @(Get-ChildItem -LiteralPath (Resolve-AkariRegPath 'HKLM:\SYSTEM\ControlSet001\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}') -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' })) {
            foreach ($n in $names) { Remove-ItemProperty -LiteralPath $k.PSPath -Name $n -ErrorAction SilentlyContinue }
        }
    }
}
