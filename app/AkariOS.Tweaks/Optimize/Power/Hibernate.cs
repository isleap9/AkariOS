using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Power;

/// <summary>src/Tweaks/Optimize/Power/Hibernate.ps1: powercfg /hibernate (it also deletes or makes hiberfil.sys) and the
/// values Windows keeps it in.</summary>
[TweakCode("power-hibernate-off")]
public sealed class Hibernate : ITweakCode
{
    private const string Key = @"HKLM:\SYSTEM\CurrentControlSet\Control\Power";

    public TweakState Detect(Tweak tweak, TweakContext c) => c.Registry.GetValue(Key, "HibernateEnabled") switch
    {
        var v when v is not null && PsSemantics.LooseEquals(v, 0) => TweakState.Optimized,
        null => TweakState.Default,
        var v when PsSemantics.LooseEquals(v, 1) => TweakState.Default,
        _ => TweakState.Custom,
    };

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        Power.Cfg(c).Run("/hibernate", "off");
        c.Registry.SetValue(Key, "HibernateEnabled", 0, "DWord");
        c.Registry.SetValue(Key, "HibernateEnabledDefault", 0, "DWord");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        Power.Cfg(c).Run("/hibernate", "on");
        c.Registry.RemoveValue(Key, "HibernateEnabled");
        c.Registry.SetValue(Key, "HibernateEnabledDefault", 1, "DWord");
    }
}

/// <summary>The Power Tweaks' powercfg.</summary>
internal static class Power
{
    public static Core.Machine.IPowerCfg Cfg(TweakContext c) => FileData.Need(c.Services.PowerCfg, "powercfg");
}
