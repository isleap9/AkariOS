# Shared by network-dns (dot-sourced by its blocks; after Chris Titus Tech's winutil, MIT, Copyright (c) 2022 CT Tech
# Group LLC: Set-WinUtilDNS). The providers are in Dns.psd1, keyed by the Choice's values. Servers are set through netsh
# (static, or back to DHCP; IPv4 and IPv6; every physical adapter). The value is read from the static IPv4 servers
# Windows keeps in the registry (NameServer): DHCP's never show there. Windows 11 also gets the provider's DoH template.

function Get-DnsProviders { (Import-PowerShellDataFile (Join-Path $PSScriptRoot 'Dns.psd1')).Providers }

# an adapter's static IPv4 servers, joined with commas ('' when automatic)
function Get-DnsStatic($Adapter) {
    $v = Get-AkariRegValue "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$($Adapter.Guid)" 'NameServer'
    @("$v" -split '[, ]+' | Where-Object { $_ }) -join ','
}

# the Choice's value: the provider every adapter's static IPv4 servers are, Default when none has any, $null for any
# other mix; no physical adapter = unreadable (Unknown)
function Get-DnsChoice {
    $adapters = @(Get-AkariDnsAdapters)
    if (-not $adapters) { throw 'no physical network adapter' }
    $p = Get-DnsProviders
    $picks = foreach ($a in $adapters) {
        $s = Get-DnsStatic $a
        if (-not $s) { 'Default'; continue }
        $hit = @($p.Keys | Where-Object { "$($p[$_].Primary),$($p[$_].Secondary)" -eq $s })
        if ($hit) { $hit[0] } else { '?' }
    }
    $u = @($picks | Select-Object -Unique)
    if ($u.Count -eq 1 -and $u[0] -ne '?') { $u[0] } else { $null }
}

# the adapter's own DoH settings (Windows 11's "DNS over HTTPS" per adapter) removed
function Clear-DnsAdapterDoh($Adapter) {
    $k = Resolve-AkariRegPath "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\$($Adapter.Guid)\DohInterfaceSettings"
    if (Test-Path -LiteralPath $k) { Remove-Item -LiteralPath $k -Recurse -Force }
}

# every physical adapter to $Value's servers, or back to DHCP for Default. Windows 11: the provider's four addresses get
# its DoH template (plain DNS still allowed if DoH is blocked) and each adapter uses it; Default removes the DoH of every
# provider's addresses (never others) and the adapters' DoH settings.
function Set-DnsChoice([string]$Value) {
    $adapters = @(Get-AkariDnsAdapters)
    if (-not $adapters) { throw 'no physical network adapter' }
    $all = Get-DnsProviders
    $doh = (Get-AkariOSBuild) -ge 22000
    if ($Value -eq 'Default') {
        foreach ($a in $adapters) {
            Invoke-AkariNetsh interface ipv4 set dnsservers "name=$($a.Index)" source=dhcp | Out-Null
            Invoke-AkariNetsh interface ipv6 set dnsservers "name=$($a.Index)" source=dhcp | Out-Null
            if ($doh) { Clear-DnsAdapterDoh $a }
        }
        if ($doh) {
            foreach ($k in @($all.Keys | Sort-Object)) {
                foreach ($ip in $all[$k].Primary, $all[$k].Secondary, $all[$k].Primary6, $all[$k].Secondary6) { Invoke-AkariNetsh dns delete encryption "server=$ip" | Out-Null }
            }
        }
    } else {
        $p = $all[$Value]
        if (-not $p) { throw "unknown value $Value" }
        foreach ($a in $adapters) {
            foreach ($f in @(@('ipv4', $p.Primary, $p.Secondary), @('ipv6', $p.Primary6, $p.Secondary6))) {
                Invoke-AkariNetsh interface $f[0] set dnsservers "name=$($a.Index)" source=static "address=$($f[1])" register=primary validate=no | Out-Null
                Invoke-AkariNetsh interface $f[0] add dnsservers "name=$($a.Index)" "address=$($f[2])" index=2 validate=no | Out-Null
            }
        }
        if ($doh) {
            foreach ($ip in $p.Primary, $p.Secondary, $p.Primary6, $p.Secondary6) {
                Invoke-AkariNetsh dns delete encryption "server=$ip" | Out-Null
                Invoke-AkariNetsh dns add encryption "server=$ip" "dohtemplate=$($p.Doh)" autoupgrade=yes udpfallback=yes | Out-Null
            }
            foreach ($a in $adapters) {
                Clear-DnsAdapterDoh $a
                $k = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters\$($a.Guid)\DohInterfaceSettings"
                foreach ($ip in $p.Primary, $p.Secondary) { Set-Reg "$k\Doh\$ip" 'DohFlags' 1 'QWord' }
                foreach ($ip in $p.Primary6, $p.Secondary6) { Set-Reg "$k\Doh6\$ip" 'DohFlags' 1 'QWord' }
            }
        }
    }
    Clear-AkariDnsCache
}
