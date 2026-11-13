# network-dns's providers (Chris Titus Tech's winutil, MIT, Copyright (c) 2022 CT Tech Group LLC: config/dns.json), keyed by
# the Choice's values: IPv4 and IPv6 servers and the DoH template.
@{
    Providers = @{
        Cloudflare        = @{ Primary = '1.1.1.1'; Secondary = '1.0.0.1'; Primary6 = '2606:4700:4700::1111'; Secondary6 = '2606:4700:4700::1001'; Doh = 'https://cloudflare-dns.com/dns-query' }
        CloudflareMalware = @{ Primary = '1.1.1.2'; Secondary = '1.0.0.2'; Primary6 = '2606:4700:4700::1112'; Secondary6 = '2606:4700:4700::1002'; Doh = 'https://security.cloudflare-dns.com/dns-query' }
        CloudflareFamily  = @{ Primary = '1.1.1.3'; Secondary = '1.0.0.3'; Primary6 = '2606:4700:4700::1113'; Secondary6 = '2606:4700:4700::1003'; Doh = 'https://family.cloudflare-dns.com/dns-query' }
        Google            = @{ Primary = '8.8.8.8'; Secondary = '8.8.4.4'; Primary6 = '2001:4860:4860::8888'; Secondary6 = '2001:4860:4860::8844'; Doh = 'https://dns.google/dns-query' }
        Quad9             = @{ Primary = '9.9.9.9'; Secondary = '149.112.112.112'; Primary6 = '2620:fe::fe'; Secondary6 = '2620:fe::9'; Doh = 'https://dns.quad9.net/dns-query' }
        OpenDns           = @{ Primary = '208.67.222.222'; Secondary = '208.67.220.220'; Primary6 = '2620:119:35::35'; Secondary6 = '2620:119:53::53'; Doh = 'https://doh.opendns.com/dns-query' }
        AdGuard           = @{ Primary = '94.140.14.14'; Secondary = '94.140.15.15'; Primary6 = '2a10:50c0::ad1:ff'; Secondary6 = '2a10:50c0::ad2:ff'; Doh = 'https://dns.adguard-dns.com/dns-query' }
        AdGuardFamily     = @{ Primary = '94.140.14.15'; Secondary = '94.140.15.16'; Primary6 = '2a10:50c0::bad1:ff'; Secondary6 = '2a10:50c0::bad2:ff'; Doh = 'https://family.adguard-dns.com/dns-query' }
    }
}
