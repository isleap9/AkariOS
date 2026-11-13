using AkariOS.Core.Apps;
using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Advanced.Features;

/// <summary>
/// src/Tweaks/Advanced/Features/Files/Features.ps1 (winutil's Invoke-WinUtilFeatureInstall): each Toggle's Windows
/// features read out of Files/Features.psd1. A feature this Windows lacks is left out; DisablePending counts as off,
/// EnablePending as on.
/// </summary>
public abstract class FeatureToggle : ITweakCode
{
    private sealed record Present(string Name, bool Default, bool On);

    private static AppPackages Dism(TweakContext c) => TweakServices.Need(c.Services.Apps, "DISM");

    /// <summary>Get-FeatureToggle: the Toggle's features (name, Windows' own state) and whether it has a Payload.</summary>
    public static (IReadOnlyList<(string Name, bool Default)> Features, bool Payload) Of(Tweak tweak, TweakContext c)
    {
        var d = PsData.Parse(c.Files.ReadText($"{TweakContext.FolderOf(tweak)}/Files/Features.psd1")).Value as PsHashtable
            ?? throw new InvalidOperationException("Features.psd1 can't be read");
        var t = d.Get(tweak.Id) as PsHashtable ?? throw new InvalidOperationException($"Features.psd1 has no {tweak.Id}");
        var features = PsSemantics.AsList(t.Get("Features")).OfType<PsHashtable>()
            .Select(f => (PsSemantics.Text(f.Get("Name"))!, string.Equals(PsSemantics.Text(f.Get("Default")), "Enabled", StringComparison.OrdinalIgnoreCase)))
            .ToList();
        return (features, PsSemantics.Truthy(t.Get("Payload")));
    }

    private static List<Present> Here(Tweak tweak, TweakContext c)
    {
        var dism = Dism(c);
        var list = new List<Present>();
        foreach (var (name, def) in Of(tweak, c).Features)
            if (dism.FeatureState(name) is { } s)
                list.Add(new Present(name, def, s.Equals("Enabled", StringComparison.OrdinalIgnoreCase) || s.Equals("EnablePending", StringComparison.OrdinalIgnoreCase)));
        return list;
    }

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var all = Here(tweak, c);
        if (all.Count == 0) return TweakState.Unknown;
        if (all.All(f => f.On)) return TweakState.Optimized;
        return all.All(f => f.On == f.Default) ? TweakState.Default : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var (features, payload) = Of(tweak, c);
        var all = Here(tweak, c);
        foreach (var (name, _) in features.Where(f => all.All(p => p.Name != f.Name)))
            c.Log.Write($"Windows features: {name} is not on this Windows, skipped");
        if (all.Count == 0) throw new InvalidOperationException("none of its Windows features is on this Windows");
        EnableNames(c, all.Where(f => !f.On).Select(f => f.Name).ToList(), payload);
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        var all = Here(tweak, c);
        if (all.Count == 0) throw new InvalidOperationException("none of its Windows features is on this Windows");
        foreach (var f in all.Where(f => f.On && !f.Default))
        {
            c.Log.Write($"Turning off {f.Name}");
            Dism(c).DisableFeature(f.Name);
        }
        EnableNames(c, all.Where(f => !f.On && f.Default).Select(f => f.Name).ToList(), payload: false);
    }

    // Enable-FeatureToggleNames: with a Payload, from a Windows setup's sources\sxs when a drive has one, else through
    // Windows Update
    private static void EnableNames(TweakContext c, IReadOnlyList<string> names, bool payload)
    {
        if (names.Count == 0) return;
        var source = payload ? AppPackages.WindowsSource(c.Services.DriveRoots()) : null;
        if (source is not null) c.Log.Write($"Windows features: files from {source}");
        void Work()
        {
            foreach (var n in names)
            {
                c.Log.Write($"Turning on {n}");
                Dism(c).EnableFeature(n, source);
            }
        }
        if (payload && source is null) UseWindowsUpdate(c, Work, "Connect to the internet, or mount a Windows ISO, and try again");
        else Work();
    }

    /// <summary>Use-WindowsUpdate: Windows Update's service turned on for <paramref name="work"/> when it is off
    /// (AkariOS' Services: Off), put back after; a failure says <paramref name="hint"/>.</summary>
    public static void UseWindowsUpdate(TweakContext c, Action work, string hint)
    {
        var services = TweakServices.Need(c.Services.Services, "service manager");
        var off = string.Equals(services.One("wuauserv")?.Start, "Disabled", StringComparison.OrdinalIgnoreCase);
        if (off)
        {
            c.Log.Write("Windows Update: on for this install");
            ServiceStart.Set(c.Registry, "wuauserv", "Manual");
        }
        try { work(); }
        catch (Exception e) { throw new InvalidOperationException($"{e.Message.TrimEnd('.')}. {hint}", e); }
        finally
        {
            if (off)
            {
                ServiceStart.Set(c.Registry, "wuauserv", "Disabled");
                c.Log.Write("Windows Update: off again");
            }
        }
    }
}
