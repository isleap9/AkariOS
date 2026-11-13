using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Network;

/// <summary>
/// src/Tweaks/Optimize/Network/Dns.ps1 (winutil W3) and its Files/Dns.ps1: a Choice over every physical adapter's DNS
/// servers, the providers read out of Files/Dns.psd1. The value = the provider every adapter's static IPv4 servers
/// (NameServer) are, Default when none has any, none of them for any other mix; no adapter = unreadable. Servers through
/// netsh (IPv4 then IPv6, static or DHCP); on Windows 11 the provider's DoH template for its four addresses and each
/// adapter's DohFlags; Default removes every provider's DoH and the adapters' DoH settings. The cache flushed after.
/// </summary>
[TweakCode("network-dns")]
public sealed class Dns : ITweakCode
{
    private const string Interfaces = @"HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces";
    private const string DohRoot = @"HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters";

    private sealed record Provider(string Name, string Primary, string Secondary, string Primary6, string Secondary6, string Doh);

    /// <summary>Dns.psd1's providers, by name (PowerShell's Sort-Object order: culture, case ignored).</summary>
    private static List<Provider> Providers(Tweak tweak, TweakContext c)
    {
        var d = PsData.Parse(c.Files.ReadText($"{TweakContext.FolderOf(tweak)}/Files/Dns.psd1")).Value as PsHashtable
            ?? throw new InvalidOperationException("Dns.psd1 can't be read");
        var p = d.Get("Providers") as PsHashtable ?? throw new InvalidOperationException("Dns.psd1 has no Providers");
        return p.Keys.Select(k => (k, h: (PsHashtable)p.Get(k)!))
            .Select(x => new Provider(x.k, Text(x.h, "Primary"), Text(x.h, "Secondary"), Text(x.h, "Primary6"), Text(x.h, "Secondary6"), Text(x.h, "Doh")))
            .OrderBy(x => x.Name, StringComparer.InvariantCultureIgnoreCase).ToList();
    }

    private static string Text(PsHashtable h, string key) => PsSemantics.Text(h.Get(key)) ?? "";

    private static IReadOnlyList<DnsAdapter> Adapters(TweakContext c)
    {
        var a = FileData.Need(c.Services.Dns, "the DNS client").Adapters();
        return a.Count == 0 ? throw new InvalidOperationException("no physical network adapter") : a;
    }

    private static INetsh Netsh(TweakContext c) => FileData.Need(c.Services.Netsh, "netsh");

    /// <summary>Get-DnsStatic: an adapter's static IPv4 servers, joined with commas.</summary>
    private static string Static(TweakContext c, DnsAdapter a) =>
        string.Join(",", (PsSemantics.Text(c.Registry.GetValue($@"{Interfaces}\{a.Guid}", "NameServer")) ?? "")
            .Split([',', ' '], StringSplitOptions.RemoveEmptyEntries));

    public object? ChoiceValue(Tweak tweak, TweakContext c)
    {
        var adapters = Adapters(c);
        var providers = Providers(tweak, c);
        var picks = adapters.Select(a =>
        {
            var s = Static(c, a);
            if (s == "") return "Default";
            return providers.FirstOrDefault(p => $"{p.Primary},{p.Secondary}" == s)?.Name ?? "?";
        }).Distinct().ToList();
        return picks.Count == 1 && picks[0] != "?" ? picks[0] : null;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value) => Set(tweak, c, PsSemantics.Text(value) ?? "");

    public void Revert(Tweak tweak, TweakContext c, object? value) => Set(tweak, c, "Default");

    private static void ClearAdapterDoh(TweakContext c, DnsAdapter a)
    {
        var k = $@"{DohRoot}\{a.Guid}\DohInterfaceSettings";
        if (c.Registry.KeyExists(k)) c.Registry.DeleteKey(k);
    }

    private static void Set(Tweak tweak, TweakContext c, string pick)
    {
        var adapters = Adapters(c);
        var all = Providers(tweak, c);
        var doh = c.System.Build >= 22000;
        var netsh = Netsh(c);
        if (pick == "Default")
        {
            foreach (var a in adapters)
            {
                netsh.Run("interface", "ipv4", "set", "dnsservers", $"name={a.Index}", "source=dhcp");
                netsh.Run("interface", "ipv6", "set", "dnsservers", $"name={a.Index}", "source=dhcp");
                if (doh) ClearAdapterDoh(c, a);
            }
            if (doh)
                foreach (var p in all)
                    foreach (var ip in new[] { p.Primary, p.Secondary, p.Primary6, p.Secondary6 })
                        netsh.Run("dns", "delete", "encryption", $"server={ip}");
        }
        else
        {
            var p = all.FirstOrDefault(x => x.Name.Equals(pick, StringComparison.OrdinalIgnoreCase))
                ?? throw new ArgumentException($"unknown value {pick}");
            foreach (var a in adapters)
                foreach (var (family, first, second) in new[] { ("ipv4", p.Primary, p.Secondary), ("ipv6", p.Primary6, p.Secondary6) })
                {
                    netsh.Run("interface", family, "set", "dnsservers", $"name={a.Index}", "source=static", $"address={first}", "register=primary", "validate=no");
                    netsh.Run("interface", family, "add", "dnsservers", $"name={a.Index}", $"address={second}", "index=2", "validate=no");
                }
            if (doh)
            {
                foreach (var ip in new[] { p.Primary, p.Secondary, p.Primary6, p.Secondary6 })
                {
                    netsh.Run("dns", "delete", "encryption", $"server={ip}");
                    netsh.Run("dns", "add", "encryption", $"server={ip}", $"dohtemplate={p.Doh}", "autoupgrade=yes", "udpfallback=yes");
                }
                foreach (var a in adapters)
                {
                    ClearAdapterDoh(c, a);
                    var k = $@"{DohRoot}\{a.Guid}\DohInterfaceSettings";
                    foreach (var ip in new[] { p.Primary, p.Secondary }) c.Registry.SetValue($@"{k}\Doh\{ip}", "DohFlags", 1, "QWord");
                    foreach (var ip in new[] { p.Primary6, p.Secondary6 }) c.Registry.SetValue($@"{k}\Doh6\{ip}", "DohFlags", 1, "QWord");
                }
            }
        }
        FileData.Need(c.Services.Dns, "the DNS client").FlushCache();
    }
}
