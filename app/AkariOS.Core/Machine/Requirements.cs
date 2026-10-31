using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Machine;

/// <summary>Whether a Tweak's Requires are met here (Test-AkariRequirement): unmet = hidden in Guided, Skipped in a Run.</summary>
public static class Requirements
{
    /// <summary>null when every Requires value is met, else the reason ("needs Win11").</summary>
    public static string? Check(Tweak t, ISystemInfo pc) => Check(t.Requires, pc);

    public static string? Check(IEnumerable<string> requires, ISystemInfo pc)
    {
        foreach (var r in requires.Where(r => !string.IsNullOrEmpty(r)))
            if (!Met(r, pc)) return $"needs {r}";
        return null;
    }

    public static bool Met(string requirement, ISystemInfo pc) => requirement.ToLowerInvariant() switch
    {
        "win10" => pc.Build < 22000,
        "win11" => pc.Build >= 22000,
        "laptop" => pc.Chassis == Chassis.Laptop,
        "desktop" => pc.Chassis == Chassis.Desktop,
        "home" => PsSemantics.Like(pc.Edition, "Core*"),
        // Pro or higher (Enterprise, Education, IoT, Server): group policies apply there, Home ignores them
        "pro" => pc.Edition.Length > 0 && !PsSemantics.Like(pc.Edition, "Core*"),
        "nvidia" or "amd" or "intel" => pc.Gpus.Any(g => string.Equals(g.Vendor, requirement, StringComparison.OrdinalIgnoreCase)),
        _ => false,
    };
}
