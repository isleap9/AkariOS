using System.Globalization;
using AkariOS.Core.Data;
using AkariOS.Core.Presets;
using AkariOS.Core.Registry;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;
using static AkariOS.Core.Data.PsSemantics;

namespace AkariOS.Core.Iso;

/// <summary>
/// A removal group of the ISO Builder's wizard (src/Core/Iso/Wizard/Groups/&lt;Id&gt;.psd1): its text, Kind (Apps,
/// Features, Capabilities, Settings, Files, Setup), Risk, Order, and what it does to the image: Store apps (patterns,
/// or 'appx:Safe' / 'appx:AkariOS' = the appx Group's rows), features (patterns), capabilities and OS packages (names),
/// install.wim's registry rows and keys, paths removed, boot.wim's rows.
/// </summary>
public sealed record IsoGroup(string Id, string Name, string Description, string Kind, string Risk, int Order,
    IReadOnlyList<string> Apps, IReadOnlyList<string> Features, IReadOnlyList<string> Capabilities, IReadOnlyList<string> Packages,
    IReadOnlyList<PsHashtable> Registry, IReadOnlyList<string> RemoveKeys, IReadOnlyList<string> Remove, IReadOnlyList<PsHashtable> Boot);

/// <summary>A mode of the wizard (src/Core/Iso/Wizard/Modes/&lt;Id&gt;.psd1): its card's text and Tag, Order, its removal
/// groups, its build settings, and AkariOS = the AkariOS preset baked in.</summary>
public sealed record IsoMode(string Id, string Name, string Description, string Tag, int Order, IReadOnlyList<string> Groups,
    IsoBuildSettings Settings, bool AkariOS);

/// <summary>One Tweak written into the image's hives: the AkariOS preset's registry-only Tweaks (Value = a Choice's).</summary>
public sealed record IsoBakeItem(Tweak Tweak, object? Value);

/// <summary>The AkariOS preset split for an image: what is written in it now, and the ids left for the first sign-in.</summary>
public sealed record IsoBake(IReadOnlyList<IsoBakeItem> InImage, IReadOnlyList<string> Later);

/// <summary>The wizard's data and its pure helpers (plan docs/plans/2026-11-20-iso-builder-wizard.md, I4).</summary>
public static class IsoWizard
{
    public const string Folder = "src/Core/Iso/Wizard/";

    /// <summary>The preset the AkariOS mode bakes in.</summary>
    public const string Preset = "AkariOS";

    /// <summary>The removal groups, by Order.</summary>
    public static IReadOnlyList<IsoGroup> Groups(ISourceFiles files) =>
        [.. Read(files, "Groups/").Select(x => Group(x.Id, x.Data)).OrderBy(g => g.Order).ThenBy(g => g.Id, StringComparer.Ordinal)];

    /// <summary>The modes, by Order.</summary>
    public static IReadOnlyList<IsoMode> Modes(ISourceFiles files) =>
        [.. Read(files, "Modes/").Select(x => Mode(x.Id, x.Data)).OrderBy(m => m.Order).ThenBy(m => m.Id, StringComparer.Ordinal)];

    private static IEnumerable<(string Id, PsHashtable Data)> Read(ISourceFiles files, string folder) =>
        files.List(Folder + folder).Where(p => p.EndsWith(".psd1", StringComparison.OrdinalIgnoreCase))
            .Select(p => (Path.GetFileNameWithoutExtension(p), (PsHashtable)PsData.Parse(files.ReadText(p)).Value!));

    private static IsoGroup Group(string id, PsHashtable h) => new(id, Text(h.Get("Name")) ?? id, Text(h.Get("Description")) ?? "",
        Text(h.Get("Kind")) ?? "", Text(h.Get("Risk")) ?? "Safe", Number(h.Get("Order")), Strings(h.Get("Apps")), Strings(h.Get("Features")),
        Strings(h.Get("Capabilities")), Strings(h.Get("Packages")), Tables(h.Get("Registry")), Strings(h.Get("RemoveKeys")),
        Strings(h.Get("Remove")), Tables(h.Get("Boot")));

    private static IsoMode Mode(string id, PsHashtable h)
    {
        var s = h.Get("Settings") as PsHashtable ?? new PsHashtable();
        var settings = new IsoBuildSettings
        {
            Compression = Enum.TryParse<IsoCompression>(Text(s.Get("Compression")), true, out var c) ? c : IsoCompression.Maximum,
            Turbo = Truthy(s.Get("Turbo")),
            CleanLeftovers = Truthy(s.Get("CleanLeftovers")),
            LeaveOutNetFx3Files = Truthy(s.Get("LeaveOutNetFx3Files")),
        };
        return new(id, Text(h.Get("Name")) ?? id, Text(h.Get("Description")) ?? "", Text(h.Get("Tag")) ?? "", Number(h.Get("Order")),
            Strings(h.Get("Groups")), settings, Truthy(h.Get("AkariOS")));
    }

    private static int Number(object? v) => Convert.ToInt32(v ?? 0, CultureInfo.InvariantCulture);
    private static IReadOnlyList<string> Strings(object? v) => [.. AsList(v).Where(Truthy).Select(x => Text(x)!)];
    private static IReadOnlyList<PsHashtable> Tables(object? v) => [.. AsList(v).OfType<PsHashtable>()];

    /// <summary>The picked groups (by id, in Order); an unknown id throws.</summary>
    public static IReadOnlyList<IsoGroup> Picked(IEnumerable<string> ids, IReadOnlyList<IsoGroup> all)
    {
        var set = ids.ToHashSet(StringComparer.OrdinalIgnoreCase);
        foreach (var id in set)
            if (!all.Any(g => g.Id.Equals(id, StringComparison.OrdinalIgnoreCase))) throw new IsoException($"Unknown removal group: {id}");
        return [.. all.Where(g => set.Contains(g.Id))];
    }

    /// <summary>
    /// The groups' app patterns, matched on the image's apps when it is built: 'appx:Safe' = the appx Group's rows
    /// rated Safe and not Keep (as Select recommended), 'appx:AkariOS' = its rows not Keep (the AkariOS preset's
    /// "appx/*"), anything else as written. <paramref name="tweaks"/> = the loaded Tweaks (Id, Risk, Keep).
    /// </summary>
    public static IReadOnlyList<string> AppPatterns(IEnumerable<IsoGroup> groups, IEnumerable<(string Id, string? Risk, bool Keep)> tweaks)
    {
        var appx = tweaks.Where(t => Like(t.Id, "appx/*")).ToList();
        var output = new List<string>();
        foreach (var a in groups.SelectMany(g => g.Apps))
        {
            IEnumerable<string> names = a.ToLowerInvariant() switch
            {
                "appx:safe" => appx.Where(t => string.Equals(t.Risk, "Safe", StringComparison.OrdinalIgnoreCase) && !t.Keep).Select(t => t.Id[5..]),
                "appx:akarios" => appx.Where(t => !t.Keep).Select(t => t.Id[5..]),
                _ => [a],
            };
            foreach (var n in names)
                if (!output.Contains(n, StringComparer.OrdinalIgnoreCase)) output.Add(n);
        }
        return output;
    }

    // ---- the AkariOS preset baked into the image

    /// <summary>
    /// The preset's Apply items split for an image of <paramref name="build"/>: in the image = a Toggle or Choice that
    /// is registry rows only (no script blocks or code, not a Group Entry or an install, not Safe Mode), whose
    /// Requires the image answers (Win10 / Win11 only) and whose every row has a place in the image's hives
    /// (<see cref="ImagePath"/>); a Choice over one row at the preset's value, else its Recommended one. The rest,
    /// by id, runs at the first sign-in.
    /// </summary>
    public static IsoBake Bake(Preset preset, IReadOnlyList<Tweak> tweaks, int build)
    {
        var inImage = new List<IsoBakeItem>();
        var later = new List<string>();
        var byId = tweaks.GroupBy(t => t.Id, StringComparer.OrdinalIgnoreCase).ToDictionary(g => g.Key, g => g.First(), StringComparer.OrdinalIgnoreCase);
        foreach (var item in PresetStore.Resolve(preset, tweaks).Items)
        {
            if (item.Mode == TweakMode.Apply && byId.TryGetValue(item.Id, out var t) && InImage(t, build) is true)
                inImage.Add(new IsoBakeItem(t, t.Kind == TweakKind.Choice ? item.Value ?? t.Recommended : null));
            else later.Add(item.Id);
        }
        return new(inImage, later);
    }

    private static bool InImage(Tweak t, int build)
    {
        if (t.Kind is not (TweakKind.Toggle or TweakKind.Choice)) return false;
        if (t.EntryKind is not null || t.Winget.Count > 0 || t.SafeMode || t.Restarts) return false;
        if (t.Blocks.Count > 0 || t.NeedsCode || t.RowsAreCode || t.Registry is not { Count: > 0 } rows) return false;
        if (t.Requires.Any(r => !(r.Equals("Win11", StringComparison.OrdinalIgnoreCase) && build >= 22000)
                             && !(r.Equals("Win10", StringComparison.OrdinalIgnoreCase) && build < 22000))) return false;
        if (t.Kind == TweakKind.Choice && (t.Recommended is null || rows[0].Name is null)) return false;
        return rows.All(r => ImagePath(r.Path) is not null);
    }

    /// <summary>
    /// A Tweak's registry path in the loaded image (under <see cref="IsoData.HiveRoot"/>), or null where the image has
    /// no place for it: HKLM's SOFTWARE and SYSTEM (CurrentControlSet = ControlSet001), HKCU = the Default user's
    /// NTUSER.DAT (but Software\Classes, which lives in a hive the Default profile doesn't have), HKEY_USERS\.DEFAULT,
    /// HKEY_CLASSES_ROOT = SOFTWARE\Classes.
    /// </summary>
    public static string? ImagePath(string path)
    {
        string hive, sub;
        try { (hive, sub) = RegPath.Split(path); }
        catch (ArgumentException) { return null; }
        string? Under(string prefix, string rest) => $@"{IsoData.HiveRoot}{prefix}{(rest.Length > 0 ? @"\" + rest : "")}";
        static bool Starts(string s, string head, out string rest)
        {
            if (s.Equals(head, StringComparison.OrdinalIgnoreCase)) { rest = ""; return true; }
            if (s.StartsWith(head + @"\", StringComparison.OrdinalIgnoreCase)) { rest = s[(head.Length + 1)..]; return true; }
            rest = "";
            return false;
        }
        switch (hive)
        {
            case "HKLM":
                if (Starts(sub, @"SYSTEM\CurrentControlSet", out var ccs)) return Under(@"SYSTEM\ControlSet001", ccs);
                if (Starts(sub, "SYSTEM", out var sys)) return Under("SYSTEM", sys);
                if (Starts(sub, "SOFTWARE", out var sw)) return Under("SOFTWARE", sw);
                return null;
            case "HKCU":
                return Starts(sub, @"Software\Classes", out _) ? null : Under("NTUSER", sub);
            case "HKU":
                return Starts(sub, ".DEFAULT", out var def) ? Under("DEFAULT", def) : null;
            case "HKCR":
                return Under(@"SOFTWARE\Classes", sub);
            default:
                return null;
        }
    }

    // ---- the first sign-in

    /// <summary>Where the AkariOS exe is in the new Windows (<see cref="IsoBuild.InImageExe"/> under C:\AkariOS).</summary>
    public const string InstalledExe = @"C:\AkariOS\AkariOS-Native.exe";

    /// <summary>The Default user's RunOnce value that finishes the AkariOS preset at each new account's first sign-in.</summary>
    public const string RunOnceKey = @"NTUSER\Software\Microsoft\Windows\CurrentVersion\RunOnce";

    public const string RunOnceName = "AkariOS";

    /// <summary>The exe's argument for that run (Program: One-click's console on the AkariOS preset).</summary>
    public const string FirstSignInArgument = "--first-sign-in";

    /// <summary>The RunOnce command: the exe started elevated through PowerShell, as a Run in phases resumes (a
    /// RunOnce entry can't start an exe that needs administrator rights by itself): one UAC prompt.</summary>
    public static string FirstSignInCommand => Runs.RunBoot.Command(InstalledExe, FirstSignInArgument);
}
