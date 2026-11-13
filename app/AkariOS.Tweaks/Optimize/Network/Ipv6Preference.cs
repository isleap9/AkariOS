using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Network;

/// <summary>src/Tweaks/Optimize/Network/Ipv6Preference.ps1 (winutil W3): a Choice over Tcpip6\DisabledComponents (its
/// Value block): 0x20 = PreferIPv4, 0x01 = TunnelsOff, 0x21 = Both, absent = Default; Teredo through netsh, disabled
/// with the tunnels, else back to its default.</summary>
[TweakCode("network-ipv6-preference")]
public sealed class Ipv6Preference : ITweakCode
{
    private const string Key = @"HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters";
    private const string Name = "DisabledComponents";

    private static readonly (string Pick, uint Value)[] Picks = [("PreferIPv4", 0x20), ("TunnelsOff", 0x01), ("Both", 0x21)];

    public object? ChoiceValue(Tweak tweak, TweakContext c)
    {
        var v = c.Registry.GetValue(Key, Name);
        if (v is null) return "Default";
        foreach (var (pick, value) in Picks) if (PsSemantics.LooseEquals(v, value)) return pick;
        return null;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var pick = PsSemantics.Text(value);
        if (pick == "Default") { Revert(tweak, c, value); return; }
        var (_, v) = Picks.FirstOrDefault(p => p.Pick == pick);
        if (v == 0) throw new ArgumentException($"unknown value {value}");
        c.Registry.SetValue(Key, Name, v, "DWord");
        Teredo(c, (v & 0x01) != 0 ? "disabled" : "default");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        c.Registry.RemoveValue(Key, Name);
        Teredo(c, "default");
    }

    private static void Teredo(TweakContext c, string state) =>
        (c.Services.Netsh ?? throw new InvalidOperationException("netsh is not available")).Run("interface", "teredo", "set", "state", state);
}
