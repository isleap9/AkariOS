# Ported from Chris Titus Tech's winutil (MIT, Copyright (c) 2022 CT Tech Group LLC), config/dns.json and
# Set-WinUtilDNS: its providers (Files\Dns.psd1), helpers in Files\Dns.ps1. No "Fastest" (a latency probe can't be read
# back). Windows' Default: every adapter on automatic (DHCP).
@{
    Id          = 'network-dns'
    Name        = 'DNS server'
    Section     = 'Optimize'
    Category    = 'Network'
    Kind        = 'Choice'
    Risk        = 'Caution'
    Guided      = $false
    Description = 'The DNS servers of every network adapter (Ethernet and Wi-Fi), IPv4 and IPv6. On Windows 11 the lookups are also encrypted (DNS over HTTPS). Automatic uses your router''s or provider''s.'
    Choices     = @(
        @{ Value = 'Cloudflare'; Label = 'Cloudflare' }
        @{ Value = 'CloudflareMalware'; Label = 'Cloudflare, blocks malware' }
        @{ Value = 'CloudflareFamily'; Label = 'Cloudflare, blocks malware and adult sites' }
        @{ Value = 'Google'; Label = 'Google' }
        @{ Value = 'Quad9'; Label = 'Quad9' }
        @{ Value = 'OpenDns'; Label = 'OpenDNS' }
        @{ Value = 'AdGuard'; Label = 'AdGuard, blocks ads and trackers' }
        @{ Value = 'AdGuardFamily'; Label = 'AdGuard, blocks ads, trackers, malware and adult sites' }
        @{ Value = 'Default'; Label = 'Automatic (DHCP)' }
    )
    Recommended = 'Cloudflare'
    Default     = 'Default'
    Value       = { . "$AkariTweakDir\Files\Dns.ps1"; Get-DnsChoice }
    Apply       = { . "$AkariTweakDir\Files\Dns.ps1"; Set-DnsChoice $AkariValue }
    Revert      = { . "$AkariTweakDir\Files\Dns.ps1"; Set-DnsChoice 'Default' }
}
