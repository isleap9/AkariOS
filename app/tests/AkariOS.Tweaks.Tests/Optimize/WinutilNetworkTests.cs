using System.Text.Json;
using AkariOS.Core.Machine;
using AkariOS.Core.Runs;
using AkariOS.Core.Tests;
using AkariOS.Core.Tweaks;
using static AkariOS.Tweaks.Tests.BlockLines;

namespace AkariOS.Tweaks.Tests.Optimize;

/// <summary>winutil W3's Network Tweaks (IPv6 preference, the Adobe block, DNS) against their PowerShell blocks
/// (Oracle/Invoke-TweakBlocks.ps1): the same registry writes, netsh calls and Choice values on the same test key.</summary>
public sealed class WinutilNetworkTests : IDisposable
{
    private readonly TweakHarness _h = new();
    private const string Ipv6 = "network-ipv6-preference";
    private const string Tcpip6 = @"HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters";

    public void Dispose() => _h.Dispose();

    private JsonElement Blocks(string id, params string[] more) => Oracle.Run("Invoke-TweakBlocks.ps1",
        ["-Src", Repo.Src, "-Ids", id, "-TestRoot", _h.KeyRoot, .. more]);

    [Fact]
    public void The_real_netsh_cant_be_made_in_a_test() => Assert.Throws<InvalidOperationException>(() => new Netsh());

    [Theory]
    [InlineData("PreferIPv4", 0x20u)]
    [InlineData("TunnelsOff", 0x01u)]
    [InlineData("Both", 0x21u)]
    public void An_ipv6_pick_writes_the_same_value_and_teredo_state(string pick, uint value)
    {
        var ps = Blocks(Ipv6, "-Value", pick);
        Assert.Equal("result Default", Lines(ps, Ipv6, "Value").Single());
        Assert.Equal("Default", _h.Engine.States.ChoiceValue(_h.Tweak(Ipv6)));

        var apply = Lines(ps, Ipv6, "Apply");
        Assert.Equal(OutcomeKind.Applied, _h.Run(Ipv6, TweakMode.Apply, pick).Kind);
        AssertWrites(_h, apply);
        Assert.Equal(value, _h.Get(Tcpip6, "DisabledComponents"));
        Assert.Equal(Of(apply, "netsh"), _h.Netsh.Calls);

        // both read the pick back off the same key
        Assert.Equal($"result {pick}", Lines(Blocks(Ipv6), Ipv6, "Value").Single());
        Assert.Equal(pick, _h.Engine.States.ChoiceValue(_h.Tweak(Ipv6)));

        _h.Netsh.Calls.Clear();
        var revert = Lines(ps, Ipv6, "Revert");
        Assert.Equal(OutcomeKind.Reverted, _h.Run(Ipv6, TweakMode.Revert).Kind);
        AssertWrites(_h, revert);
        Assert.Equal(Of(revert, "netsh"), _h.Netsh.Calls);
        Assert.Equal("Default", _h.Engine.States.ChoiceValue(_h.Tweak(Ipv6)));
    }

    [Fact]
    public void A_disabled_components_value_set_by_hand_is_none_of_the_picks()
    {
        _h.Set(Tcpip6, "DisabledComponents", 0xFFu, "DWord");
        Assert.Equal("result ", Lines(Blocks(Ipv6), Ipv6, "Value").Single());
        Assert.Null(_h.Engine.States.ChoiceValue(_h.Tweak(Ipv6)));
        Assert.Equal(TweakState.Custom, _h.State(Ipv6));
    }

    // ---- DNS: two physical adapters, their static servers in the test key

    private const string Dns = "network-dns";
    private const string G1 = "{11111111-1111-1111-1111-111111111111}";
    private const string G2 = "{22222222-2222-2222-2222-222222222222}";
    private const string Ifs = @"HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces";
    private const string DohRoot = @"HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\InterfaceSpecificParameters";
    private const string TwoAdapters = $"12|Ethernet|{G1};7|Wi-Fi|{G2}";

    private void Adapters()
    {
        _h.Dns.List.Add(new DnsAdapter(12, "Ethernet", G1));
        _h.Dns.List.Add(new DnsAdapter(7, "Wi-Fi", G2));
    }

    private JsonElement DnsBlocks(string adapters, int build, string value = "Cloudflare") =>
        Blocks(Dns, "-DnsAdapters", adapters, "-Build", build.ToString(), "-Value", value);

    [Theory]
    [InlineData("", "", "Default")]
    [InlineData("1.1.1.1,1.0.0.1", "1.1.1.1 1.0.0.1", "Cloudflare")]
    [InlineData("94.140.14.15,94.140.15.16", "94.140.14.15,94.140.15.16", "AdGuardFamily")]
    [InlineData("1.1.1.1,1.0.0.1", "", "")]
    [InlineData("8.8.8.8", "8.8.8.8", "")]
    public void Dns_reads_the_same_value_off_the_static_servers(string ethernet, string wifi, string want)
    {
        Adapters();
        if (ethernet != "") _h.Set($@"{Ifs}\{G1}", "NameServer", ethernet, "String");
        if (wifi != "") _h.Set($@"{Ifs}\{G2}", "NameServer", wifi, "String");
        Assert.Equal($"result {want}", Lines(DnsBlocks(TwoAdapters, 26100), Dns, "Value").Single());
        Assert.Equal(want == "" ? null : want, _h.Engine.States.ChoiceValue(_h.Tweak(Dns)));
    }

    [Theory]
    [InlineData("Quad9", 26100)]
    [InlineData("AdGuard", 26100)]
    [InlineData("Google", 19045)]
    public void A_dns_pick_runs_the_same_netsh_and_doh_settings(string pick, int build)
    {
        Adapters();
        _h.Pc.Build = build;
        // an earlier provider's DoH setting on the Ethernet adapter: both sides clear it first (Windows 11)
        _h.Set($@"{DohRoot}\{G1}\DohInterfaceSettings\Doh\1.1.1.1", "DohFlags", 1UL, "QWord");
        var ps = DnsBlocks(TwoAdapters, build, pick);

        var apply = Lines(ps, Dns, "Apply");
        var o = _h.Run(Dns, TweakMode.Apply, pick);
        Assert.Equal((OutcomeKind.Applied, ""), (o.Kind, o.Message ?? ""));
        Assert.Equal(Of(apply, "netsh"), _h.Netsh.Calls);
        Assert.Equal(Of(apply, "flushdns").Count, _h.Dns.Flushes);
        if (build >= 22000)
        {
            // the key is deleted, then written again: the values set are there, the earlier provider's is gone
            AssertWrites(_h, Of(apply, "set"));
            Assert.Contains($@"delkey {DohRoot}\{G1}\DohInterfaceSettings", apply);
            Assert.Null(_h.Get($@"{DohRoot}\{G1}\DohInterfaceSettings\Doh\1.1.1.1", "DohFlags"));
        }
        else Assert.Empty(Of(apply, "set", "delkey"));

        // Revert: both adapters back on DHCP, every provider's DoH removed (Windows 11)
        _h.Netsh.Calls.Clear();
        _h.Dns.Flushes = 0;
        var p = PsProvider(pick);
        _h.Set($@"{Ifs}\{G1}", "NameServer", p, "String");
        _h.Set($@"{Ifs}\{G2}", "NameServer", p, "String");
        var revert = Lines(ps, Dns, "Revert");
        Assert.Equal(OutcomeKind.Reverted, _h.Run(Dns, TweakMode.Revert).Kind);
        Assert.Equal(Of(revert, "netsh"), _h.Netsh.Calls);
        Assert.Equal(Of(revert, "flushdns").Count, _h.Dns.Flushes);
        if (build >= 22000)
        {
            Assert.Equal(32, Of(revert, "netsh").Count(l => l.StartsWith("netsh dns delete encryption ", StringComparison.Ordinal)));
            AssertWrites(_h, revert);
        }
    }

    // a provider's IPv4 servers as Windows keeps them (for the Revert's "from" state)
    private static string PsProvider(string pick) => pick switch
    {
        "Quad9" => "9.9.9.9,149.112.112.112",
        "AdGuard" => "94.140.14.14,94.140.15.15",
        _ => "8.8.8.8,8.8.4.4",
    };

    [Fact]
    public void Dns_with_no_physical_adapter_is_unknown_and_fails_the_same()
    {
        var ps = DnsBlocks(";", 26100);
        Assert.Equal("result ", Lines(ps, Dns, "Value").Last());
        Assert.Equal(TweakState.Unknown, _h.State(Dns));
        var o = _h.Run(Dns, TweakMode.Apply, "Cloudflare");
        Assert.Equal((OutcomeKind.Failed, Lines(ps, Dns, "Apply").Last()[6..]), (o.Kind, o.Message));
        Assert.Empty(_h.Netsh.Calls);
    }

    [Fact]
    public void The_real_dns_client_cant_be_made_in_a_test() => Assert.Throws<InvalidOperationException>(() => new WmiDnsClient());
}
