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
            case "CapabilityRemove": Apps(c).RemoveCapability(name); break;
            case "FeatureDisable": Apps(c).DisableFeature(name); break;
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
}
