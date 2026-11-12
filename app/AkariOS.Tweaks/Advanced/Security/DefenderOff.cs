using System.Text.RegularExpressions;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Advanced.Security;

/// <summary>src/Tweaks/Advanced/Security/DefenderOff.ps1: the values of Files/defender-off.psd1 (a service row only when
/// this Windows has the service's key), the keys Defender guards (services, Windows Defender) written as
/// TrustedInstaller and then every row as admin, smartscreen.exe stopped and moved out of System32 as TrustedInstaller
/// (and back on Revert). Detect: the rows, and where smartscreen.exe is.</summary>
[TweakCode("security-defender-off")]
public sealed partial class DefenderOff : ITweakCode
{
    [GeneratedRegex(@"\\Services\\")]
    private static partial Regex Service();

    [GeneratedRegex(@"\\Services\\|\\Windows Defender\\")]
    private static partial Regex Guarded();

    public static IReadOnlyList<RegistryRow> AllRows(Tweak tweak, TweakContext c) => DefenderRows.Read(tweak, c, "defender-off.psd1");

    public static IReadOnlyList<RegistryRow> Rows(Tweak tweak, TweakContext c) =>
        AllRows(tweak, c).Where(r => !Service().IsMatch(r.Path) || c.Registry.KeyExists(r.Path)).ToList();

    public static IReadOnlyList<RegistryRow> TrustedRows(IEnumerable<RegistryRow> rows) => rows.Where(r => Guarded().IsMatch(r.Path)).ToList();

    private static (string System32, string Moved) SmartScreen(TweakContext c)
    {
        var windows = TweakServices.Folder(c.Services.Windows, "Windows");
        return (Path.Combine(windows, "System32", "smartscreen.exe"), Path.Combine(windows, "smartscreen.exe"));
    }

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var s = c.Registry.State(Rows(tweak, c), c.System.Build);
        var (inSystem32, moved) = SmartScreen(c);
        if (s == TweakState.Unknown) return TweakState.Unknown;
        if (s == TweakState.Optimized && !File.Exists(inSystem32)) return TweakState.Optimized;
        if (s == TweakState.Default && !File.Exists(moved)) return TweakState.Default;
        return TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value) => Set(tweak, c, TweakMode.Apply);

    public void Revert(Tweak tweak, TweakContext c, object? value) => Set(tweak, c, TweakMode.Revert);

    private static void Set(Tweak tweak, TweakContext c, TweakMode mode)
    {
        var rows = Rows(tweak, c);
        DefenderRows.Write(c, TrustedRows(rows), rows, mode, r => $"{r.Path} {r.Name}");
        TweakServices.Need(c.Services.Processes, "process list").Stop("smartscreen");
        var (system32, moved) = SmartScreen(c);
        var (from, to) = mode == TweakMode.Apply ? (system32, moved) : (moved, system32);
        if (File.Exists(from))
            TweakServices.Need(c.Services.Trusted, "TrustedInstaller")
                .Start(Path.Combine(Path.GetDirectoryName(system32)!, "cmd.exe"), $"/c move /y \"{from}\" \"{to}\"");
    }
}
