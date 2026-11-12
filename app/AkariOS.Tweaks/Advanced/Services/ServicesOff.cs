using System.Globalization;
using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Advanced.Services;

/// <summary>src/Tweaks/Advanced/Services/ServicesOff.ps1 (and Files/ServiceRows.ps1): a Choice over the start types
/// of Files/services.psd1, read from the file: Off (FR33THY), Light and Manual (ZOICWARE), Default (Windows'). Only the
/// services this Windows has. Written as TrustedInstaller (many service keys are protected), then as admin for what
/// that missed. A SafeMode Tweak: the Runner runs it in Safe Mode.</summary>
[TweakCode("advanced-services-off")]
public sealed class ServicesOff : ITweakCode
{
    public static IReadOnlyList<string> Picks { get; } = ["Default", "Off", "Light", "Manual"];

    /// <summary>Get-ServiceRows: the Start rows of a pick (Value = its start type, Default = Windows').</summary>
    public static IReadOnlyList<RegistryRow> Rows(Tweak tweak, TweakContext c, string pick)
    {
        var d = PsData.Parse(c.Files.ReadText($"{TweakContext.FolderOf(tweak)}/Files/services.psd1")).Value as PsHashtable
            ?? throw new InvalidOperationException("services.psd1 can't be read");
        var light = PsSemantics.AsList(d.Get("Light")).Select(PsSemantics.Text).ToHashSet(StringComparer.OrdinalIgnoreCase);
        var manual = PsSemantics.AsList(d.Get("Manual")).Select(PsSemantics.Text).ToHashSet(StringComparer.OrdinalIgnoreCase);
        var rows = new List<RegistryRow>();
        foreach (var s in PsSemantics.AsList(d.Get("Services")).OfType<PsHashtable>())
        {
            var name = PsSemantics.Text(s.Get("Name"))!;
            var def = Convert.ToInt32(s.Get("Default"), CultureInfo.InvariantCulture);
            var v = pick switch
            {
                "Off" => s.Get("Off") is { } off ? Convert.ToInt32(off, CultureInfo.InvariantCulture) : def,
                "Light" => light.Contains(name) ? 4 : def,
                "Manual" => manual.Contains(name) ? 3 : def,
                _ => def,
            };
            var path = $@"{ServiceStart.Root}\{name}";
            if (c.Registry.KeyExists(path)) rows.Add(new RegistryRow(path, "Start", "DWord", v, OsValue.Both(def), false));
        }
        return rows;
    }

    /// <summary>Get-ServicePick: the pick every row is at now, or null (a start type changed by hand).</summary>
    public object? ChoiceValue(Tweak tweak, TweakContext c)
    {
        var now = Rows(tweak, c, "Default").ToDictionary(r => r.Path, r => c.Registry.GetValue(r.Path, "Start"), StringComparer.OrdinalIgnoreCase);
        return Picks.FirstOrDefault(p => Rows(tweak, c, p).All(r => RegistryEngine.Matches(now[r.Path], r.Value)));
    }

    public void Apply(Tweak tweak, TweakContext c, object? value) => Set(tweak, c, PsSemantics.Text(value) ?? "Default");

    public void Revert(Tweak tweak, TweakContext c, object? value) => Set(tweak, c, "Default");

    // Set-ServicePick: as TrustedInstaller, then as admin for what that missed
    private static void Set(Tweak tweak, TweakContext c, string pick)
    {
        var rows = Rows(tweak, c, pick);
        c.Registry.Invoke(rows, TweakMode.Apply, c.System.Build, asTrusted: true);
        foreach (var r in rows)
        {
            try { c.Registry.Invoke([r], TweakMode.Apply, c.System.Build); }
            catch (Exception e) when (e is UnauthorizedAccessException or System.Security.SecurityException or IOException) { c.Log.Write($"Kept by Windows: {r.Path} ({e.Message})"); }
        }
    }
}
