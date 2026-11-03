using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Network;

/// <summary>src/Tweaks/Optimize/Network/IPv4Only.ps1: every adapter keeps only IPv4. The State is IPv6's binding
/// (ms_tcpip6) on every adapter; Revert turns every one of the bindings back on, IPv4 too.</summary>
[TweakCode("network-ipv4-only")]
public sealed class IPv4Only : ITweakCode
{
    public static readonly IReadOnlyList<string> Off = ["ms_lldp", "ms_lltdio", "ms_implat", "ms_rspndr", "ms_tcpip6", "ms_server", "ms_msclient", "ms_pacer"];
    public static readonly IReadOnlyList<string> On = ["ms_lldp", "ms_lltdio", "ms_implat", "ms_tcpip", "ms_rspndr", "ms_tcpip6", "ms_server", "ms_msclient", "ms_pacer"];

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var b = FileData.Need(c.Services.Bindings, "network bindings").Get("ms_tcpip6");
        if (b.Count == 0) return TweakState.Unknown;
        var on = b.Count(x => x);
        return on == 0 ? TweakState.Optimized : on == b.Count ? TweakState.Default : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value) => Set(c, Off, false);

    public void Revert(Tweak tweak, TweakContext c, object? value) => Set(c, On, true);

    // -ErrorAction SilentlyContinue: a binding that won't change doesn't stop the others
    private static void Set(TweakContext c, IReadOnlyList<string> components, bool enabled)
    {
        var bindings = FileData.Need(c.Services.Bindings, "network bindings");
        foreach (var id in components)
        {
            try { bindings.Set(id, enabled); }
            catch (Exception e) when (e is System.Management.ManagementException or System.Runtime.InteropServices.COMException or UnauthorizedAccessException)
            { c.Log.Write($"Warning: {id}: {e.Message}"); }
        }
    }
}
