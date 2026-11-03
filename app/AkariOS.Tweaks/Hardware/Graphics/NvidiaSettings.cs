using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Hardware.Graphics;

/// <summary>
/// src/Tweaks/Hardware/Graphics/NvidiaSettings.ps1: the driver's NVTweak values, the adapters' RmProfilingAdminOnly, no
/// tray at sign-in, the legacy sharpening filter, then FR33THY's profile (Files\nvidia-base-profile.nip) imported with
/// NVIDIA Profile Inspector; Revert removes the values, turns the filter back and imports the empty profile. Detect
/// reads the registry part only (the profile can't be read back).
/// </summary>
[TweakCode("graphics-nvidia-settings")]
public sealed class NvidiaSettings : ITweakCode
{
    public const string NvTweak = @"HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\Global\NVTweak";
    private const string Tray = @"HKCU:\Software\NVIDIA Corporation\NvTray";
    private static readonly string[] FtsKeys = [NvidiaLegacySharpen.Fts, NvidiaLegacySharpen.ParametersFts];

    /// <summary>FR33THY's registry part is there (ReBarForce's Revert picks its profile by this too).</summary>
    public static bool Fr33thy(TweakContext c) =>
        PsSemantics.LooseEquals(c.Registry.GetValue(NvTweak, "NvCplPhysxAuto"), 0) && PsSemantics.LooseEquals(c.Registry.GetValue(NvTweak, "NvDevToolsVisible"), 1);

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        object?[] v = [c.Registry.GetValue(NvTweak, "NvCplPhysxAuto"), c.Registry.GetValue(NvTweak, "NvDevToolsVisible"), c.Registry.GetValue(Tray, "StartOnLogin")];
        if (PsSemantics.LooseEquals(v[0], 0) && PsSemantics.LooseEquals(v[1], 1) && PsSemantics.LooseEquals(v[2], 0)) return TweakState.Optimized;
        return v.All(x => x is null) ? TweakState.Default : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        ProfileInspector.UnblockDrs(c);
        var reg = c.Registry;
        reg.SetValue(NvTweak, "NvCplPhysxAuto", 0, "DWord");
        reg.SetValue(NvTweak, "NvDevToolsVisible", 1, "DWord");
        reg.SetValue(NvTweak, "RmProfilingAdminOnly", 0, "DWord");
        foreach (var g in GpuValues.Of(c, "NVIDIA")) reg.SetValue(g.Path, "RmProfilingAdminOnly", 0, "DWord");
        reg.SetValue(Tray, "StartOnLogin", 0, "DWord");
        foreach (var k in FtsKeys) reg.SetValue(k, "EnableGR535", 0, "DWord");
        var exe = ProfileInspector.Ensure(c);
        ProfileInspector.Shortcut(c, exe);
        ProfileInspector.Import(tweak, c, exe, "nvidia-base-profile.nip");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        ProfileInspector.UnblockDrs(c);
        var reg = c.Registry;
        foreach (var n in new[] { "NvCplPhysxAuto", "NvDevToolsVisible", "RmProfilingAdminOnly" }) reg.RemoveValue(NvTweak, n);
        foreach (var g in GpuValues.Of(c, "NVIDIA")) reg.RemoveValue(g.Path, "RmProfilingAdminOnly");
        reg.RemoveValue(Tray, "StartOnLogin");
        foreach (var k in FtsKeys) reg.SetValue(k, "EnableGR535", 1, "DWord");
        ProfileInspector.Import(tweak, c, ProfileInspector.Ensure(c), "nvidia-default-profile.nip");
    }
}
