using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Advanced.SystemTweaks; // not .System: it would hide .NET's System namespace

/// <summary>src/Tweaks/Advanced/System/MMAgent.ps1: the Prefetcher (EnablePrefetcher 0 / 3) and the memory agent's
/// launch prefetching, prelaunch, operation recorder (MaxOperationAPIFiles 1 / 512) off; page combining off both ways.
/// Each memory agent call may fail on its own (-ErrorAction SilentlyContinue): logged, the rest goes on.</summary>
[TweakCode("system-mmagent-off")]
public sealed class MMAgent : ITweakCode
{
    private const string Prefetch = @"HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters";

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var m = FileData.Need(c.Services.Memory, "memory agent").Get();
        var pf = c.Registry.GetValue(Prefetch, "EnablePrefetcher");
        if (!m.ApplicationLaunchPrefetching && !m.ApplicationPreLaunch && !m.OperationAPI && m.MaxOperationAPIFiles == 1 && PsSemantics.LooseEquals(pf, 0))
            return TweakState.Optimized;
        if (m.ApplicationLaunchPrefetching && m.ApplicationPreLaunch && m.OperationAPI && m.MaxOperationAPIFiles == 512 && PsSemantics.LooseEquals(pf, 3))
            return TweakState.Default;
        return TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value) => Write(c, on: false);

    public void Revert(Tweak tweak, TweakContext c, object? value) => Write(c, on: true);

    private static void Write(TweakContext c, bool on)
    {
        c.Registry.SetValue(Prefetch, "EnablePrefetcher", on ? 3 : 0, "DWord");
        var agent = FileData.Need(c.Services.Memory, "memory agent");
        Try(c, () => agent.Set("ApplicationLaunchPrefetching", on));
        Try(c, () => agent.Set("ApplicationPreLaunch", on));
        Try(c, () => agent.SetMaxOperationAPIFiles(on ? 512u : 1u));
        Try(c, () => agent.Set("OperationAPI", on));
        Try(c, () => agent.Set("PageCombining", false));
    }

    private static void Try(TweakContext c, Action step)
    {
        try { step(); }
        catch (Exception e) when (e is System.Management.ManagementException or InvalidOperationException or System.Runtime.InteropServices.COMException)
        {
            c.Log.Write($"Warning: memory agent: {e.Message}");
        }
    }
}
