# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/tweaks.json "WPFTweaksIPv46"
# and "WPFTweaksTeredo": one Choice, as both write Tcpip6\DisabledComponents (0x20 prefers IPv4, 0x01 turns the
# tunnel interfaces off; Teredo is also set through netsh). Windows has no DisabledComponents: IPv6 first, tunnels on.
@{
    Id          = 'network-ipv6-preference'
    Name        = 'IPv6 preference'
    Section     = 'Optimize'
    Category    = 'Network'
    Kind        = 'Choice'
    Risk        = 'Caution'
    Guided      = $false
    Reboot      = $true
    Description = 'Whether Windows tries IPv4 before IPv6, and whether the IPv6 tunnels (Teredo, 6to4, ISATAP) stay on. IPv6 itself keeps working. Needs a restart.'
    Choices     = @(
        @{ Value = 'PreferIPv4'; Label = 'Prefer IPv4' }
        @{ Value = 'TunnelsOff'; Label = 'IPv6 tunnels off' }
        @{ Value = 'Both'; Label = 'Prefer IPv4, tunnels off' }
        @{ Value = 'Default'; Label = 'IPv6 first, tunnels on' }
    )
    Recommended = 'PreferIPv4'
    Default     = 'Default'
    Value       = {
        $v = Get-AkariRegValue 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' 'DisabledComponents'
        if ($null -eq $v) { 'Default' } elseif ($v -eq 0x20) { 'PreferIPv4' } elseif ($v -eq 0x01) { 'TunnelsOff' } elseif ($v -eq 0x21) { 'Both' } else { $null }
    }
    Apply       = {
        $k = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters'
        switch ($AkariValue) {
            'PreferIPv4' { Set-Reg $k 'DisabledComponents' 0x20 'DWord'; Invoke-AkariNetsh interface teredo set state default | Out-Null }
            'TunnelsOff' { Set-Reg $k 'DisabledComponents' 0x01 'DWord'; Invoke-AkariNetsh interface teredo set state disabled | Out-Null }
            'Both' { Set-Reg $k 'DisabledComponents' 0x21 'DWord'; Invoke-AkariNetsh interface teredo set state disabled | Out-Null }
            'Default' { Remove-Reg $k 'DisabledComponents'; Invoke-AkariNetsh interface teredo set state default | Out-Null }
            default { throw "unknown value $AkariValue" }
        }
    }
    Revert      = {
        Remove-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' 'DisabledComponents'
        Invoke-AkariNetsh interface teredo set state default | Out-Null
    }
}
