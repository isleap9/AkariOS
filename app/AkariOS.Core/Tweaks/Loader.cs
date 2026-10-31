using System.Text.RegularExpressions;
using AkariOS.Core.Data;
using AkariOS.Core.Sources;
using static AkariOS.Core.Data.PsSemantics;

namespace AkariOS.Core.Tweaks;

/// <summary>
/// Reads the one-file Tweaks (src/Tweaks/&lt;Section&gt;/&lt;Category&gt;/*.ps1) through PsData, with the rules of
/// src/Core/Loader.ps1 (docs/PLAN.md §7): required fields, kebab-case unique ids, Risk, Kind, Requires, the folder,
/// the Toggle / Choice / Action shapes, key rows, Winget, the '# Action:' line, no interactive blocks, one owner per
/// registry value, data-list Groups and their Entries. A file that breaks a rule is a Problem and is left out.
/// Legacy (src/Tweaks/*.ps1, Ported.psd1) is never read.
/// </summary>
public sealed partial class Loader(ISourceFiles files, IReadOnlyDictionary<string, ITweakCode> codes)
{
    public const string TweaksRoot = "src/Tweaks/";

    /// <summary>Requires values the engine knows (Test-AkariRequirement).</summary>
    public static readonly IReadOnlyList<string> Requirements = ["Win10", "Win11", "Laptop", "Desktop", "Home", "Pro", "NVIDIA", "AMD", "Intel"];

    private static readonly string[] BlockFields = ["Apply", "Revert", "Detect", "Check", "Before", "After", "Prepare", "Value"];

    [GeneratedRegex("^[a-z0-9]+(-[a-z0-9]+)*$")]
    private static partial Regex KebabId();

    [GeneratedRegex(@"(?m)^\s*#\s*Action:\s*\S")]
    private static partial Regex ActionLine();

    [GeneratedRegex(@"(?i)\b(Pause|Read-Host|Clear-Host)\b")]
    private static partial Regex Interactive();

    [GeneratedRegex(@"^[\w.+-]+$")]
    private static partial Regex WingetId();

    [GeneratedRegex("^[A-Z0-9]+$", RegexOptions.IgnoreCase)]
    private static partial Regex StoreProductId();

    private sealed class LoadError(string message) : Exception(message);

    /// <summary>The one-file Tweak files, sorted as the PowerShell Loader sorts them (it matters for "already used").</summary>
    public IReadOnlyList<string> TweakFiles() =>
        files.List(TweaksRoot)
            .Where(p => p.Split('/') is { Length: 5 } parts && parts[4].EndsWith(".ps1", StringComparison.OrdinalIgnoreCase))
            .Order(StringComparer.InvariantCultureIgnoreCase)
            .ToList();

    public LoadResult Load()
    {
        var tweaks = new List<Tweak>();
        var groups = new List<TweakGroup>();
        var problems = new List<Problem>();
        var seen = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        var owners = new OwnerIndex();

        foreach (var path in TweakFiles())
        {
            object loaded;
            try { loaded = Import(path); }
            catch (LoadError e) { problems.Add(new(path, "Error", e.Message)); continue; }

            if (loaded is TweakGroup g)
            {
                if (!seen.TryAdd(g.Id, path)) { problems.Add(new(path, "Error", $"Id '{g.Id}' is already used by {seen[g.Id]}")); continue; }
                groups.Add(g);
                if (!g.EntryKind.Rows) continue;
                foreach (var row in g.Rows)
                {
                    var e = NewEntry(g, row);
                    if (!seen.TryAdd(e.Id, path)) { problems.Add(new(path, "Error", $"Id '{e.Id}' is already used by {seen[e.Id]}")); continue; }
                    tweaks.Add(e);
                }
                continue;
            }

            var t = (Tweak)loaded;
            if (!seen.TryAdd(t.Id, path)) { problems.Add(new(path, "Error", $"Id '{t.Id}' is already used by {seen[t.Id]}")); continue; }
            if (t.Kind == TweakKind.Toggle && !t.Has("Detect") && t.Registry is null && !t.RowsAreCode)
                problems.Add(new(path, "Warning", "no Detect: State falls back to what Akari last applied"));
            if (t.Registry is { Count: > 0 })
            {
                var owner = owners.Find(t);
                if (owner != null)
                {
                    problems.Add(new(path, "Error", $"a registry value of '{t.Id}' is already owned by '{owner}' (one owner per value)"));
                    seen.Remove(t.Id);
                    continue;
                }
                owners.Add(t);
            }
            if (!t.NeedsCode && codes.ContainsKey(t.Id))
                problems.Add(new(path, "Error", $"'{t.Id}' has a C# class, but its file is data only: the data already defines it"));
            tweaks.Add(t);
        }
        return new LoadResult(tweaks, groups, problems);
    }

    // ---- one file

    private object Import(string path)
    {
        var rel = path[TweaksRoot.Length..];
        var text = files.ReadText(path);
        PsFile file;
        try { file = PsData.Parse(text); }
        catch (PsDataException e) { throw new LoadError($"{rel}: {e.Message}"); }
        if (file.Value is not PsHashtable h) throw new LoadError($"{rel}: the file must return one hashtable");

        foreach (var f in new[] { "Id", "Name", "Description", "Section", "Category", "Risk" })
            if (!Truthy(h.Get(f))) throw new LoadError($"{rel}: missing {f}");
        var id = Text(h.Get("Id"))!;
        if (!KebabId().IsMatch(id)) throw new LoadError($"{rel}: Id '{id}' must be kebab-case");
        if (!TryName(Text(h.Get("Risk")), out Risk risk))
            throw new LoadError($"{rel}: Risk must be Safe, Caution or Advanced");

        var kindText = Text(h.Get("Kind"));
        var kind = TweakKind.Toggle;
        if (Truthy(h.Get("Kind")) && !TryName(kindText, out kind))
            throw new LoadError($"{rel}: Kind must be Toggle, Choice, Action or Group");

        var section = Text(h.Get("Section"))!;
        var category = Text(h.Get("Category"))!;
        var parts = path.Split('/');
        if (!string.Equals(parts[3], category, StringComparison.OrdinalIgnoreCase) || !string.Equals(parts[2], section, StringComparison.OrdinalIgnoreCase))
            throw new LoadError($"{rel}: Section/Category '{section}/{category}' must match the folder '{parts[2]}/{parts[3]}'");

        if (kind == TweakKind.Group) return ImportGroup(path, rel, h, id, risk, section, category);

        var requires = AsList(h.Get("Requires")).Where(Truthy).Select(r => Text(r)!).ToList();
        foreach (var r in requires)
            if (!Requirements.Contains(r, StringComparer.OrdinalIgnoreCase))
                throw new LoadError($"{rel}: Requires '{r}' is not one of {string.Join(", ", Requirements)}");

        bool Has(string field) => Truthy(h.Get(field));
        var blocks = BlockFields.Where(b => h.Get(b) is PsScriptBlock).ToHashSet();
        var safeMode = Truthy(h.Get("SafeMode"));
        var editable = Truthy(h.Get("Editable"));

        // rows: a hashtable each; a row PsData kept as code (a foreach) can't be checked or owned here
        var rowsAreCode = h.Get("Registry") is PsCode;
        List<RegistryRow>? rows = null;
        var rowTables = new List<PsHashtable>();
        if (Has("Registry") && !rowsAreCode)
        {
            rows = [];
            foreach (var item in AsList(h.Get("Registry")))
            {
                // a row with code in it (Default = (& $w11 'Key')) is the C#'s to give, like a foreach row
                if (item is PsHashtable row && !PsData.HasCode(row)) rowTables.Add(row);
                else rowsAreCode = true;
            }
        }

        if (Has("Value") && kind != TweakKind.Choice) throw new LoadError($"{rel}: Value is only for a Choice");
        if (Has("Prepare") && !safeMode) throw new LoadError($"{rel}: Prepare is only for a SafeMode Tweak (it runs before the restart into Safe Mode)");

        var hasRegistry = Has("Registry");
        switch (kind)
        {
            case TweakKind.Toggle:
                if (!hasRegistry && !(Has("Apply") && Has("Revert"))) throw new LoadError($"{rel}: a Toggle needs Registry, or both Apply and Revert");
                if (Has("After") && !hasRegistry) throw new LoadError($"{rel}: After on a Toggle needs Registry (Apply / Revert blocks do the whole job)");
                foreach (var e in rowTables) CheckToggleRow(rel, e);
                break;
            case TweakKind.Choice:
                if (Has("Value"))
                {
                    if (hasRegistry || !(Has("Apply") && Has("Revert"))) throw new LoadError($"{rel}: a Choice with Value needs Apply and Revert, and no Registry");
                    if (editable) throw new LoadError($"{rel}: a Choice with Value can't be Editable");
                }
                else
                {
                    if (!hasRegistry || AsList(h.Get("Registry")).Count != 1) throw new LoadError($"{rel}: a Choice needs exactly one Registry entry (or Value, Apply and Revert)");
                    foreach (var k in new[] { "Path", "Name", "Type" })
                        if (rowTables.Count == 1 && !rowTables[0].ContainsKey(k)) throw new LoadError($"{rel}: Registry entry is missing {k}");
                }
                if (!Has("Choices")) throw new LoadError($"{rel}: a Choice needs Choices");
                foreach (var k in new[] { "Recommended", "Default" })
                    if (!h.ContainsKey(k)) throw new LoadError($"{rel}: a Choice needs {k}");
                if (!editable && !AsList(h.Get("Choices")).Any(c => c is PsHashtable ch && LooseEquals(ch.Get("Value"), h.Get("Recommended"))))
                    throw new LoadError($"{rel}: Recommended must be one of the Choices");
                break;
            case TweakKind.Action:
                if (Has("Winget"))
                {
                    if (Has("Apply")) throw new LoadError($"{rel}: an Action with Winget gets its Apply from the engine; put extra steps in Before / After");
                    foreach (var w in AsList(h.Get("Winget")))
                        if (!WingetId().IsMatch(Text(w) ?? "")) throw new LoadError($"{rel}: Winget id '{Text(w)}' is not a package id");
                    var src = Has("WingetSource") ? Text(h.Get("WingetSource")) : "winget";
                    if (!string.Equals(src, "winget", StringComparison.OrdinalIgnoreCase) && !string.Equals(src, "msstore", StringComparison.OrdinalIgnoreCase))
                        throw new LoadError($"{rel}: WingetSource must be winget or msstore");
                }
                else
                {
                    if (Has("After") || Has("Before")) throw new LoadError($"{rel}: Before and After are only for an Action with Winget");
                    if (!Has("Apply")) throw new LoadError($"{rel}: an Action needs Apply");
                }
                if (!ActionLine().IsMatch(text)) throw new LoadError($"{rel}: an Action file needs a '# Action: <why it can't be a Toggle>' line");
                break;
        }
        foreach (var b in new[] { "Apply", "Revert", "Detect", "Check" })
            if (h.Get(b) is PsScriptBlock sb && Interactive().Match(sb.Text) is { Success: true } m)
                throw new LoadError($"{rel}: {b} uses {m.Groups[1].Value}; tweaks must not be interactive");

        foreach (var e in rowTables)
        {
            if (ToRow(e) is { } row) rows!.Add(row);
            else rowsAreCode = true;
        }

        var needsCode = file.HasCode;
        return new Tweak
        {
            Id = id,
            Name = Text(h.Get("Name"))!,
            Description = Text(h.Get("Description")),
            Section = section,
            Category = category,
            Kind = kind,
            Risk = risk,
            Button = Has("Button") ? Text(h.Get("Button"))! : "Run",
            Confirm = Text(h.Get("Confirm")),
            Reboot = Truthy(h.Get("Reboot")),
            SafeMode = safeMode,
            Restarts = Truthy(h.Get("Restarts")),
            Explorer = Truthy(h.Get("Explorer")),
            AkariOS = Truthy(h.Get("AkariOS")),
            Guided = IsGuided(h.Get("Guided")),
            Editable = editable,
            Requires = requires,
            Registry = rows,
            RowsAreCode = rowsAreCode,
            Choices = AsList(h.Get("Choices")).OfType<PsHashtable>().Select(ToChoice).ToList(),
            Recommended = h.Get("Recommended"),
            Default = h.Get("Default"),
            Winget = AsList(h.Get("Winget")).Select(w => Text(w)!).ToList(),
            WingetSource = Text(h.Get("WingetSource")),
            AppType = Text(h.Get("AppType")),
            StoreId = Text(h.Get("StoreId")),
            Group = Text(h.Get("Group")),
            Package = Text(h.Get("Package")),
            Keep = Truthy(h.Get("Keep")),
            Blocks = blocks,
            NeedsCode = needsCode,
            Code = needsCode && codes.TryGetValue(id, out var code) ? code : null,
            Source = path,
            Fields = h,
        };
    }

    private static void CheckToggleRow(string rel, PsHashtable e)
    {
        if (!e.ContainsKey("Name"))
        {
            // a key row: the whole key exists ('Key') or is deleted ($null); Default may be a per-OS map
            foreach (var k in new[] { "Path", "Value", "Default" })
                if (!e.ContainsKey(k)) throw new LoadError($"{rel}: key row is missing {k}");
            var defs = e.Get("Default") is PsHashtable perOs ? perOs.Values.ToList() : [e.Get("Default")];
            foreach (var x in defs.Prepend(e.Get("Value")))
                if (x is not null && !string.Equals(Text(x), "Key", StringComparison.OrdinalIgnoreCase))
                    throw new LoadError($"{rel}: key row '{Text(e.Get("Path"))}': Value and Default must be 'Key' or $null");
            if (e.Get("Value") is null && defs.All(d => d is null))
                throw new LoadError($"{rel}: key row '{Text(e.Get("Path"))}': Value and Default are both $null");
            return;
        }
        foreach (var k in new[] { "Path", "Name", "Type", "Value" })
            if (!e.ContainsKey(k)) throw new LoadError($"{rel}: Registry entry is missing {k}");
        if (!e.ContainsKey("Default"))
            throw new LoadError($"{rel}: Registry entry '{Text(e.Get("Name"))}' is missing Default (use $null to delete on Revert)");
    }

    // an enum by its name only (Enum.TryParse would also take "1")
    private static bool TryName<T>(string? text, out T value) where T : struct, Enum
    {
        value = default;
        var name = Enum.GetNames<T>().FirstOrDefault(n => string.Equals(n, text, StringComparison.OrdinalIgnoreCase));
        return name != null && Enum.TryParse(name, out value);
    }

    // shown in Guided too unless the file says Guided = $false ($h['Guided'] -ne $false)
    private static bool IsGuided(object? v) => !(v is false || IsNumber(v) && Convert.ToDecimal(v) == 0);

    /// <summary>A Registry row hashtable as a row (no Name key = a key row), or null when its Path isn't text.</summary>
    public static RegistryRow? ToRow(PsHashtable e)
    {
        if (e.Get("Path") is not string p) return null;
        var keyRow = !e.ContainsKey("Name");
        return new RegistryRow(p, keyRow ? null : Text(e.Get("Name")), Text(e.Get("Type")), e.Get("Value"), ToOsValue(e.Get("Default")), keyRow);
    }

    private static OsValue ToOsValue(object? v) =>
        v is PsHashtable h && (h.ContainsKey("Win10") || h.ContainsKey("Win11")) ? new OsValue(h.Get("Win10"), h.Get("Win11")) : OsValue.Both(v);

    private static ChoiceValue ToChoice(PsHashtable c) =>
        new(c.Get("Value"), Text(c.Get("Label")) ?? Text(c.Get("Value")) ?? "",
            TryName(Text(c.Get("Risk")), out Risk r) ? r : null);

    // ---- data-list Groups (ADR 0002)

    private TweakGroup ImportGroup(string path, string rel, PsHashtable h, string id, Risk risk, string section, string category)
    {
        var kind = EntryKind.Find(Text(h.Get("EntryKind")));
        if (!Truthy(h.Get("EntryKind")) || kind is null)
            throw new LoadError($"{rel}: a Group needs an EntryKind ({string.Join(", ", EntryKind.All.Select(k => k.Name).Order(StringComparer.Ordinal))})");
        var entries = h.Get("Entries");
        if (entries is PsImport im) entries = ReadImport(path, rel, im);
        if (!Truthy(entries)) throw new LoadError($"{rel}: a Group needs Entries");
        var rows = new List<PsHashtable>();
        foreach (var r in AsList(entries))
        {
            if (r is not PsHashtable row || !Truthy(row.Get("Name"))) throw new LoadError($"{rel}: every Entry needs a Name");
            if (Truthy(row.Get("Risk")) && !TryName(Text(row.Get("Risk")), out Risk _))
                throw new LoadError($"{rel}: Entry '{Text(row.Get("Name"))}': Risk must be Safe, Caution or Advanced");
            if (kind == EntryKind.StoreInstall && !StoreProductId().IsMatch(Text(row.Get("StoreId")) ?? ""))
                throw new LoadError($"{rel}: Entry '{Text(row.Get("Name"))}': StoreId must be a Microsoft Store product id");
            rows.Add(row);
        }
        foreach (var r in AsList(h.Get("Requires")).Where(Truthy))
            if (!Requirements.Contains(Text(r)!, StringComparer.OrdinalIgnoreCase))
                throw new LoadError($"{rel}: Requires '{Text(r)}' is not one of {string.Join(", ", Requirements)}");
        return new TweakGroup
        {
            Id = id,
            Name = Text(h.Get("Name"))!,
            Description = Text(h.Get("Description")),
            Section = section,
            Category = category,
            Risk = risk,
            EntryKind = kind,
            Rows = rows,
            KeepNames = AsList(h.Get("KeepNames")).Select(k => Text(k)!).ToList(),
            AppType = Text(h.Get("AppType")),
            Source = path,
        };
    }

    private object? ReadImport(string path, string rel, PsImport im)
    {
        var file = SourceFilesExtensions.Combine(SourceFilesExtensions.Folder(path), im.File);
        if (!files.Exists(file)) throw new LoadError($"{rel}: {im.File} is missing");
        try { return (PsData.Parse(files.ReadText(file)).Value as PsHashtable)?.Get(im.Key); }
        catch (PsDataException e) { throw new LoadError($"{rel}: {im.File}: {e.Message}"); }
    }

    /// <summary>The data file row that names an Entry (a row Name may have wildcards; a capability's name before its
    /// version counts too: 'App.StepsRecorder~~~~0.0.1.0' -> row 'App.StepsRecorder').</summary>
    public static PsHashtable? EntryRow(TweakGroup g, string name)
    {
        var bare = g.EntryKind == EntryKind.CapabilityRemove ? name.Split('~')[0] : name;
        return g.Rows.FirstOrDefault(r => Like(name, Text(r.Get("Name"))) || Like(bare, Text(r.Get("Name"))));
    }

    /// <summary>
    /// One Entry of a data-list Group: id '&lt;group-id&gt;/&lt;name&gt;', an Action that does the Group's job.
    /// The row is a data file row, or only Name (something on this PC the file doesn't list: named after itself,
    /// Risk Caution). Keep: the row says so, or the name matches one of the Group's KeepNames; a kept item with no
    /// Risk of its own is Advanced.
    /// </summary>
    public static Tweak NewEntry(TweakGroup g, PsHashtable row)
    {
        var name = Text(row.Get("Name"))!;
        var known = EntryRow(g, name);
        if (known != null && !Truthy(row.Get("Display")))
            foreach (var f in new[] { "Display", "Description", "Risk", "Keep", "StoreId" })
                if (row.Get(f) is null && known.Get(f) is not null) row = row.With(f, known.Get(f));
        var keep = Truthy(row.Get("Keep")) || g.KeepNames.Any(k => Like(name, k));
        var risk = TryName(Text(row.Get("Risk")), out Risk r) ? r : keep ? Risk.Advanced : Risk.Caution;
        return new Tweak
        {
            Id = $"{g.Id}/{name}",
            Name = Truthy(row.Get("Display")) ? Text(row.Get("Display"))! : name,
            Description = Text(row.Get("Description")),
            Section = g.Section,
            Category = g.Category,
            Kind = TweakKind.Action,
            Button = g.EntryKind.Button,
            Reboot = g.EntryKind.Reboot,
            Risk = risk,
            Keep = keep,
            Group = g.Id,
            Package = name,
            EntryKind = g.EntryKind,
            StoreId = Text(row.Get("StoreId")),
            AppType = g.AppType,
            Source = g.Source,
            Fields = row,
        };
    }

    /// <summary>An Entry id that is not a loaded Tweak (an installed app, a feature), built from its name; null when
    /// no Group owns the id.</summary>
    public static Tweak? ResolveEntry(IEnumerable<TweakGroup> groups, string id)
    {
        var g = groups.FirstOrDefault(x => id.StartsWith(x.Id + "/", StringComparison.Ordinal));
        if (g is null || id.Length <= g.Id.Length + 1) return null;
        return NewEntry(g, PsHashtable.Of(("Name", id[(g.Id.Length + 1)..])));
    }

    // ---- one owner per registry value

    /// <summary>
    /// The rows loaded so far (Find-AkariRegistryOwner): a row clashes with an earlier Tweak's when both set the same
    /// value, when it is inside an earlier key row, or when it is a key row with an earlier row inside it.
    /// </summary>
    private sealed class OwnerIndex
    {
        private readonly Dictionary<string, string> _valueRows = new(StringComparer.OrdinalIgnoreCase);
        private readonly Dictionary<string, string> _keyRows = new(StringComparer.OrdinalIgnoreCase);
        private readonly Dictionary<string, string> _under = new(StringComparer.OrdinalIgnoreCase);

        private static string Normal(string path)
        {
            var p = path.StartsWith(@"HKEY_CURRENT_USER\", StringComparison.OrdinalIgnoreCase) ? @"HKCU:\" + path[18..]
                : path.StartsWith(@"HKEY_LOCAL_MACHINE\", StringComparison.OrdinalIgnoreCase) ? @"HKLM:\" + path[19..] : path;
            return p.TrimEnd('\\').ToLowerInvariant();
        }

        private static IEnumerable<string> Parents(string path)
        {
            for (var q = path; ; q = q[..q.LastIndexOf('\\')])
            {
                yield return q;
                if (!q.Contains('\\')) yield break;
            }
        }

        public void Add(Tweak t)
        {
            foreach (var e in t.Registry!)
            {
                var p = Normal(e.Path);
                if (e.IsKeyRow) _keyRows.TryAdd(p, t.Id);
                else _valueRows.TryAdd($"{p}|{e.Name}", t.Id);
                foreach (var q in Parents(p)) _under.TryAdd(q, t.Id);
            }
        }

        public string? Find(Tweak t)
        {
            foreach (var e in t.Registry!)
            {
                var p = Normal(e.Path);
                var o = e.IsKeyRow ? _under.GetValueOrDefault(p) : _valueRows.GetValueOrDefault($"{p}|{e.Name}");
                if (o != null) return o;
                foreach (var q in Parents(p))
                    if (_keyRows.TryGetValue(q, out var k)) return k;
            }
            return null;
        }
    }
}
