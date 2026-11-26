using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Apps;

/// <summary>
/// What the engine does for an Entry of a data-list Group ($AkariEntryKinds in src/Core/Loader.ps1: AppxRemove,
/// CapabilityRemove, FeatureDisable, StoreInstall; the Entry's Package is its name) and for a Tweak with a Winget field
/// (Before, each id installed, After; done = every id installed). Not a Tweak's logic: the kinds are the engine's.
/// </summary>
public static class AppKinds
{
    /// <summary>The engine runs it (an Entry, or a Tweak with Winget).</summary>
    public static bool Handles(Tweak t) => t.EntryKind is not null || t.Winget.Count > 0;

    private static AppPackages Apps(TweakContext c) => c.Services.Apps ?? throw new NotSupportedException("the engine can't change apps");

    private static Winget Winget(TweakContext c) => c.Services.Winget ?? throw new NotSupportedException("the engine can't install with winget");

    private static string Source(Tweak t) => t.WingetSource ?? "winget";

    /// <summary>Already done: the app gone or there, the capability gone, the feature off, every winget id installed.</summary>
    public static bool Done(Tweak t, TweakContext c)
    {
        var name = t.Package ?? "";
        return t.EntryKind?.Name switch
        {
            "AppxRemove" => !Apps(c).IsInstalled(name),
            "CapabilityRemove" => !Apps(c).CapabilityInstalled(name),
            "FeatureDisable" => !Apps(c).FeatureEnabled(name),
            "StoreInstall" => Apps(c).IsInstalled(name),
            null => t.Winget.All(id => Winget(c).Installed(id, Source(t))),
            var k => throw new NotSupportedException($"unknown EntryKind '{k}'"),
        };
    }

    /// <summary>Does it (an Action: Apply only).</summary>
    public static void Apply(Tweak t, TweakContext c)
    {
        var name = t.Package ?? "";
        switch (t.EntryKind?.Name)
        {
            case "AppxRemove": Apps(c).Remove(name); break;
            case "CapabilityRemove": Permanent(() => Apps(c).RemoveCapability(name)); break;
            case "FeatureDisable": Permanent(() => Apps(c).DisableFeature(name)); break;
            case "StoreInstall": Winget(c).Install(t.StoreId ?? throw new InvalidOperationException($"{t.Id} has no StoreId"), "msstore"); break;
            case null:
                var w = Winget(c);
                if (t.Has("Before")) t.Code!.Before(t, c);
                foreach (var id in t.Winget) w.Install(id, Source(t));
                if (t.Has("After")) t.Code!.After(t, c, TweakMode.Apply);
                break;
            case var k: throw new NotSupportedException($"unknown EntryKind '{k}'");
        }
    }

    // CBS_E_CANNOT_UNINSTALL: a permanent part of this Windows (the display language's Language.Basic, SmbDirect):
    // nothing AkariOS can do, so Skipped, not Failed
    private static void Permanent(Action remove)
    {
        try { remove(); }
        catch (DismException e) when (e.Code == DismException.CannotUninstall)
        {
            throw new SkippedException("Windows won't remove it: it is a permanent part of this Windows (0x800F0825)");
        }
    }

    /// <summary>Uninstall-AkariApp (after winutil's Invoke-WPFUnInstall): every winget id of an app the Downloads page
    /// installs, last first, going on after one fails. Not a Revert (an Action has none): its own Outcome, Reverted =
    /// uninstalled, Already = not installed, Skipped = nothing winget may uninstall here (no winget id, a per-user
    /// install, or RemoveWith: its own removal under Remove apps). Nothing an install added is undone.</summary>
    public static Outcome Uninstall(Tweak t, TweakContext c)
    {
        Outcome Skipped(string why)
        {
            c.Log.Write($"Skipped: {t.Name} ({why})");
            return new Outcome(t.Id, TweakMode.Revert, OutcomeKind.Skipped, false, why);
        }
        if (!string.IsNullOrEmpty(t.RemoveWith)) return Skipped("has its own removal: use Remove apps");
        if (t.Winget.Count == 0) return Skipped("not installed with winget: uninstall it from Windows' Installed apps");
        var got = new List<WingetUninstall>();
        var errors = new List<string>();
        foreach (var id in t.Winget.Reverse())
        {
            try { got.Add(Winget(c).Uninstall(id, Source(t))); }
            catch (Exception e) { errors.Add(e.Message); }
        }
        if (errors.Count > 0)
        {
            var message = string.Join("; ", errors);
            c.Log.Write($"Failed: {t.Name}: {message}");
            return new Outcome(t.Id, TweakMode.Revert, OutcomeKind.Failed, false, message);
        }
        if (got.Contains(WingetUninstall.Uninstalled) || got.Contains(WingetUninstall.Restart))
        {
            c.Log.Write($"Uninstalled: {t.Name}");
            return new Outcome(t.Id, TweakMode.Revert, OutcomeKind.Reverted, got.Contains(WingetUninstall.Restart));
        }
        if (got.Contains(WingetUninstall.UserOnly)) return Skipped("installed for this user only: uninstall it from Windows' Installed apps");
        c.Log.Write($"Already: {t.Name} (not installed)");
        return new Outcome(t.Id, TweakMode.Revert, OutcomeKind.Already, false, "not installed");
    }

    /// <summary>Get-AkariInstalledApps (the Downloads page's "Show installed"): the ids of the app installs on this PC:
    /// every winget id of the Tweak in winget's list (read once), else its own Detect; an install with neither is
    /// never listed. A hint only.</summary>
    public static IReadOnlyList<string> InstalledApps(IEnumerable<Tweak> tweaks, TweakContext c)
    {
        var apps = tweaks.Where(t => t.Group is null).ToList();
        var lines = c.Services.Winget?.List() ?? [];
        var have = global::AkariOS.Core.Apps.Winget.InstalledIds(lines, apps.SelectMany(t => t.Winget)).ToHashSet(StringComparer.OrdinalIgnoreCase);
        bool On(Tweak t)
        {
            if (t.Winget.Count > 0) return t.Winget.All(have.Contains);
            if (!t.Has("Detect") || t.Code is null) return false;
            try { return t.Code.Detect(t, c) == TweakState.Optimized; } catch (Exception) { return false; }
        }
        return apps.Where(On).Select(t => t.Id).ToList();
    }
}
