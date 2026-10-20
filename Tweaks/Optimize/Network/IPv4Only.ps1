# Ported from AkariOS-Ultimate (FR33THY Ultimate) 6 Windows\27 Network IPv4 Only (One-click does the same): every
# adapter keeps only IPv4. Revert turns every binding back on.
@{
    Id          = 'network-ipv4-only'
    Name        = 'IPv4 only'
    Section     = 'Optimize'
    Category    = 'Network'
    Risk        = 'Caution'
    AkariOS     = $true
    Description = 'Adapters keep only IPv4: no IPv6, file and printer sharing, network discovery or QoS. Shared folders on this PC and others stop working.'
    Detect      = {
        $b = @(Get-NetAdapterBinding -ComponentID 'ms_tcpip6' -ErrorAction SilentlyContinue)
        if (-not $b.Count) { return 'Unknown' }
        $on = @($b | Where-Object { $_.Enabled }).Count
        if ($on -eq 0) { 'Optimized' } elseif ($on -eq $b.Count) { 'Default' } else { 'Custom' }
    }
    Apply       = {
        foreach ($c in 'ms_lldp', 'ms_lltdio', 'ms_implat', 'ms_rspndr', 'ms_tcpip6', 'ms_server', 'ms_msclient', 'ms_pacer') {
            Disable-NetAdapterBinding -Name '*' -ComponentID $c -ErrorAction SilentlyContinue
        }
    }
    Revert      = {
        foreach ($c in 'ms_lldp', 'ms_lltdio', 'ms_implat', 'ms_tcpip', 'ms_rspndr', 'ms_tcpip6', 'ms_server', 'ms_msclient', 'ms_pacer') {
            Enable-NetAdapterBinding -Name '*' -ComponentID $c -ErrorAction SilentlyContinue
        }
    }
}
