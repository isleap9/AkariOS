using System.Globalization;
using System.Text.Json;
using System.Text.Json.Nodes;
using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Tweaks;
using Microsoft.Win32;

namespace AkariOS.Core.Runs;

/// <summary>A value as it was before a Run (Read-AkariUndoRow): missing, or its kind and data (Binary as hex text).</summary>
public sealed record UndoRow(string Path, string Name, bool Exists, string Kind, object? Data);

/// <summary>A history record: the Run's name and time, each recorded Tweak's rows before it, the Outcomes.</summary>
public sealed record HistoryRecord(string Path, string Name, string When, IReadOnlyDictionary<string, IReadOnlyList<UndoRow>> Before,
    IReadOnlyList<(string Id, TweakMode Mode, OutcomeKind Kind)> Outcomes);

/// <summary>What Undo does with a record (Get-AkariUndoPlan).</summary>
public sealed record UndoPlan(IReadOnlyList<string> Exact, IReadOnlyList<string> Default, IReadOnlyList<string> Never);

/// <summary>
/// Run history and Undo (src/Core/History.ps1, plan 2026-11-26-new-features.md X4): before a Run changes a Tweak whose
/// effect is only its value rows, each row is saved as it was; Undo writes them back (the user's own values, not only
/// Windows' defaults). Tweaks with code go back to Windows' default (their Revert); Actions and apps can't be undone
/// here. Records: <c>history\&lt;yyyyMMdd-HHmmss&gt;.json</c> in the native app's folder, the PowerShell app's shape;
/// the newest <see cref="Keep"/> kept; an undone one renamed <c>.undone</c>, so the next Undo goes one Run further back.
/// </summary>
public sealed class RunHistory(string folder, RegistryEngine registry, IAkariLog log)
{
    public const int Keep = 10;

    public string Folder { get; } = folder;

    /// <summary>New-AkariHistory: a record for a Run; older ones past <see cref="Keep"/> removed.</summary>
    public string New(string name, DateTime now)
    {
        Directory.CreateDirectory(Folder);
        var stamp = now.ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture);
        var path = System.IO.Path.Combine(Folder, $"{stamp}.json");
        for (var k = 2; File.Exists(path); k++) path = System.IO.Path.Combine(Folder, $"{stamp}-{k}.json");
        Save(new HistoryRecord(path, name, now.ToString("o", CultureInfo.InvariantCulture), new Dictionary<string, IReadOnlyList<UndoRow>>(), []));
        foreach (var old in Directory.GetFiles(Folder).OrderByDescending(f => f, StringComparer.OrdinalIgnoreCase).Skip(Keep))
            try { File.Delete(old); } catch (IOException) { }
        return path;
    }

    private static void Save(HistoryRecord r)
    {
        var before = new JsonObject();
        foreach (var (id, rows) in r.Before)
            before[id] = new JsonArray([.. rows.Select(x => new JsonObject
            {
                ["Path"] = x.Path, ["Name"] = x.Name, ["Exists"] = x.Exists, ["Kind"] = x.Kind,
                ["Data"] = x.Data is null ? null : JsonSerializer.SerializeToNode(x.Data, x.Data.GetType()),
            })]);
        var json = new JsonObject
        {
            ["Name"] = r.Name, ["When"] = r.When, ["Before"] = before,
            ["Outcomes"] = new JsonArray([.. r.Outcomes.Select(o => new JsonObject { ["Id"] = o.Id, ["Mode"] = o.Mode.ToString(), ["Outcome"] = o.Kind.ToString() })]),
        };
        File.WriteAllText(r.Path, json.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
    }

    /// <summary>Read-AkariHistory: null when it can't be read.</summary>
    public static HistoryRecord? Read(string path)
    {
        try
        {
            var j = JsonDocument.Parse(File.ReadAllText(path)).RootElement;
            string S(JsonElement e, string n) => e.TryGetProperty(n, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString() ?? "" : "";
            var before = new Dictionary<string, IReadOnlyList<UndoRow>>(StringComparer.OrdinalIgnoreCase);
            if (j.TryGetProperty("Before", out var b) && b.ValueKind == JsonValueKind.Object)
                foreach (var p in b.EnumerateObject())
                    before[p.Name] = (p.Value.ValueKind == JsonValueKind.Array ? p.Value.EnumerateArray() : default)
                        .Where(x => x.ValueKind == JsonValueKind.Object)
                        .Select(x => new UndoRow(S(x, "Path"), S(x, "Name"), x.TryGetProperty("Exists", out var e) && e.ValueKind == JsonValueKind.True,
                            S(x, "Kind"), x.TryGetProperty("Data", out var d) ? DataOf(d) : null)).ToList();
            var outs = new List<(string, TweakMode, OutcomeKind)>();
            if (j.TryGetProperty("Outcomes", out var os) && os.ValueKind == JsonValueKind.Array)
                foreach (var o in os.EnumerateArray())
                    if (Enum.TryParse<TweakMode>(S(o, "Mode"), true, out var m) && Enum.TryParse<OutcomeKind>(S(o, "Outcome"), true, out var k))
                        outs.Add((S(o, "Id"), m, k));
            return new HistoryRecord(path, S(j, "Name"), S(j, "When"), before, outs);
        }
        catch (Exception e) when (e is IOException or JsonException or UnauthorizedAccessException or InvalidOperationException) { return null; }
    }

    private static object? DataOf(JsonElement d) => d.ValueKind switch
    {
        JsonValueKind.Number when d.TryGetUInt64(out var u) => u,
        JsonValueKind.Number when d.TryGetInt64(out var l) => l,
        JsonValueKind.String => d.GetString(),
        JsonValueKind.Array => d.EnumerateArray().Select(x => x.ToString()).ToArray(),
        _ => null,
    };

    /// <summary>Get-AkariLastHistory: the newest record not undone, or null.</summary>
    public HistoryRecord? Last()
    {
        if (!Directory.Exists(Folder)) return null;
        var f = Directory.GetFiles(Folder, "*.json").OrderByDescending(x => x, StringComparer.OrdinalIgnoreCase).FirstOrDefault();
        return f is null ? null : Read(f);
    }

    /// <summary>Test-AkariUndoable (pure): a Toggle or Choice of value rows only, no script block or rows built with
    /// code, not a Group Entry, an install or a Safe Mode one.</summary>
    public static bool Undoable(Tweak t) =>
        t.Kind is TweakKind.Toggle or TweakKind.Choice && t.EntryKind is null && !t.SafeMode && t.Winget.Count == 0
        && t.Blocks.Count == 0 && !t.RowsAreCode && t.Registry is { Count: > 0 } rows && rows.All(r => !r.IsKeyRow);

    /// <summary>Read-AkariUndoRow.</summary>
    public UndoRow ReadRow(string path, string name)
    {
        if (registry.GetRaw(path, name) is not { } raw) return new UndoRow(path, name, false, "", null);
        object data = raw.Kind switch
        {
            RegistryValueKind.Binary => string.Join(",", ((byte[])raw.Data).Select(x => x.ToString("x2", CultureInfo.InvariantCulture))),
            RegistryValueKind.MultiString => (string[])raw.Data,
            _ => raw.Data,
        };
        return new UndoRow(path, name, true, raw.Kind.ToString(), data);
    }

    /// <summary>Add-AkariHistoryBefore for a Run's items: each undoable Tweak's rows as they are, once per record.</summary>
    public void AddBefore(string record, IEnumerable<Tweak?> tweaks)
    {
        try
        {
            if (Read(record) is not { } r) return;
            var before = new Dictionary<string, IReadOnlyList<UndoRow>>(r.Before, StringComparer.OrdinalIgnoreCase);
            foreach (var t in tweaks)
                if (t is not null && Undoable(t) && !before.ContainsKey(t.Id))
                    before[t.Id] = t.Registry!.Select(row => ReadRow(row.Path, row.Name!)).ToList();
            Save(r with { Before = before });
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or System.Security.SecurityException) { log.WriteFile($"history: {e.Message}"); }
    }

    public void AddOutcomes(string record, IEnumerable<Outcome> outcomes)
    {
        try
        {
            if (Read(record) is not { } r) return;
            Save(r with { Outcomes = [.. r.Outcomes, .. outcomes.Where(o => o.Id.Length > 0).Select(o => (o.Id, o.Mode, o.Kind))] });
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { log.WriteFile($"history: {e.Message}"); }
    }

    /// <summary>A Run recorded: its record, the rows before, the Runner's Run, the Outcomes.</summary>
    public IReadOnlyList<Outcome> Record(string name, DateTime now, IReadOnlyList<PlanItem> items, Func<string, Tweak?> find,
        Func<IReadOnlyList<Outcome>> run)
    {
        var record = New(name, now);
        AddBefore(record, items.Select(i => find(i.Id)));
        var outcomes = run();
        AddOutcomes(record, outcomes);
        return outcomes;
    }

    /// <summary>Get-AkariUndoPlan (pure): by each id's last Applied / Reverted Outcome, in the Run's order.</summary>
    public static UndoPlan Plan(HistoryRecord r, Func<string, Tweak?> find)
    {
        var last = new List<(string Id, TweakMode Mode)>();
        foreach (var o in r.Outcomes.Where(o => o.Kind is OutcomeKind.Applied or OutcomeKind.Reverted))
        {
            last.RemoveAll(x => string.Equals(x.Id, o.Id, StringComparison.OrdinalIgnoreCase));
            last.Add((o.Id, o.Mode));
        }
        var (exact, def, never) = (new List<string>(), new List<string>(), new List<string>());
        foreach (var (id, mode) in last)
        {
            var t = find(id);
            if (t is not null && r.Before.ContainsKey(id)) exact.Add(id);
            else if (t is not null && t.Kind is TweakKind.Toggle or TweakKind.Choice && t.EntryKind is null && mode == TweakMode.Apply && t.Winget.Count == 0) def.Add(id);
            else never.Add(id);
        }
        return new UndoPlan(exact, def, never);
    }

    /// <summary>Get-AkariUndoText (pure): the question Undo asks.</summary>
    public static string UndoText(HistoryRecord r, UndoPlan plan, Func<string, Tweak?> find)
    {
        string Name(string id) => find(id)?.Name ?? id;
        var when = DateTime.TryParse(r.When, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var w) ? w.ToString("d MMM yyyy, HH:mm", CultureInfo.InvariantCulture) : r.When;
        var lines = new List<string> { $"Undo \"{r.Name}\" from {when}?", "" };
        var (n, d, x) = (plan.Exact.Count, plan.Default.Count, plan.Never.Count);
        if (n > 0) lines.Add($"- {n} setting{(n != 1 ? "s" : "")} go back to what {(n != 1 ? "they were" : "it was")} before the Run");
        if (d > 0) lines.Add($"- {d} go back to Windows' default (they run code, so their earlier values weren't saved): {string.Join(", ", plan.Default.Select(Name))}");
        if (x > 0) lines.Add($"- {x} can't be undone here (apps, one-time actions): {string.Join(", ", plan.Never.Select(Name))}");
        return string.Join('\n', lines);
    }

    /// <summary>Restore-AkariUndoRow: missing = removed, else its kind and data.</summary>
    public void RestoreRow(UndoRow row)
    {
        if (!row.Exists) { registry.RemoveValue(row.Path, row.Name); return; }
        object? data = row.Kind switch
        {
            "MultiString" => row.Data as string[] ?? [],
            "DWord" => System.Convert.ToUInt32(row.Data, CultureInfo.InvariantCulture),
            "QWord" => System.Convert.ToUInt64(row.Data, CultureInfo.InvariantCulture),
            _ => row.Data,
        };
        registry.SetValue(row.Path, row.Name, data, row.Kind);
    }

    /// <summary>Invoke-AkariUndo: the Exact ids' rows written back (their expected.json entry forgotten), the Default ones
    /// Reverted, in reverse order; Explorer restarted once when a Tweak needs it. The record renamed .undone when
    /// nothing failed.</summary>
    public IReadOnlyList<Outcome> Undo(HistoryRecord r, Func<string, Tweak?> find, Runner runner, IExplorer explorer, ExpectedStore? expected,
        IProgress<RunProgress>? progress = null)
    {
        var plan = Plan(r, find);
        var ids = plan.Exact.Concat(plan.Default).Reverse().ToList();
        var outs = new List<Outcome>();
        var restart = false;
        for (var i = 0; i < ids.Count; i++)
        {
            var t = find(ids[i])!;
            progress?.Report(new RunProgress(i, ids.Count, t.Name));
            Outcome o;
            if (plan.Exact.Contains(t.Id))
            {
                try
                {
                    foreach (var row in r.Before[t.Id]) RestoreRow(row);
                    expected?.Remove(t.Id);
                    log.Write($"Reverted: {t.Name} (as it was before the Run)");
                    o = new Outcome(t.Id, TweakMode.Revert, OutcomeKind.Reverted, false, "as it was before the Run");
                }
                catch (Exception e) when (e is IOException or UnauthorizedAccessException or System.Security.SecurityException or ArgumentException or FormatException or InvalidCastException)
                {
                    log.Write($"Failed: {t.Name}: {e.Message}");
                    o = new Outcome(t.Id, TweakMode.Revert, OutcomeKind.Failed, false, e.Message);
                }
            }
            else o = runner.Run(t, TweakMode.Revert);
            if (t.Explorer && o.Kind == OutcomeKind.Reverted) restart = true;
            outs.Add(o);
        }
        if (restart) explorer.Restart();
        progress?.Report(new RunProgress(ids.Count, ids.Count, "Done"));
        if (!outs.Any(o => o.Kind == OutcomeKind.Failed))
            try { File.Move(r.Path, System.IO.Path.ChangeExtension(r.Path, ".undone"), overwrite: true); } catch (IOException) { }
        return outs;
    }
}
