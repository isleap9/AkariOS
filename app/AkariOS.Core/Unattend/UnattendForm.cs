using System.Text.Json;
using AkariOS.Core.Data;
using AkariOS.Core.Sources;

namespace AkariOS.Core.Unattend;

public enum FormKind { Radio, Check, Input, Select, Checks }

/// <summary>A dropdown's or a multi-select's choice: the field value and what the form shows.</summary>
public sealed record FormChoice(string Id, string Name);

/// <summary>
/// One field of the form and its value (UI\UnattendForm.ps1's bindings): a radio group (<see cref="Value"/> = the
/// picked option), a checkbox (<see cref="On"/>), a text box (<see cref="Value"/>), a dropdown (<see cref="Value"/>
/// among <see cref="Choices"/>) or a multi-select (<see cref="Picked"/>). It counts only while its gates (the radio
/// options and checkboxes of the branches it sits in) are picked.
/// </summary>
public sealed class FormBinding(string field, FormKind kind, IReadOnlyList<FormGate> gates, IReadOnlyList<FormChoice>? choices = null)
{
    public string Field { get; } = field;
    public FormKind Kind { get; } = kind;
    public IReadOnlyList<FormGate> Gates { get; } = gates;

    /// <summary>A dropdown's choices (a value its list lacks is added first), a multi-select's or radio group's options.</summary>
    public List<FormChoice> Choices { get; } = [.. choices ?? []];

    public string? Value { get; private set; }
    public bool On { get; private set; }
    public IReadOnlyList<string> Picked { get; private set; } = [];

    /// <summary>The value changed (by the user or by the form being filled).</summary>
    public event Action? Changed;

    public bool Counts => Gates.All(g => g.Open);

    /// <summary>A radio option, a dropdown value or a text box's text.</summary>
    public void Pick(string? value)
    {
        if (value == Value) return;
        Value = value;
        Changed?.Invoke();
    }

    public void SetOn(bool on)
    {
        if (on == On) return;
        On = on;
        Changed?.Invoke();
    }

    /// <summary>A multi-select's ids, kept in the order of its options.</summary>
    public void SetPicked(IEnumerable<string> ids)
    {
        var set = ids.ToHashSet();
        var picked = Choices.Where(c => set.Contains(c.Id)).Select(c => c.Id).ToList();
        if (picked.SequenceEqual(Picked)) return;
        Picked = picked;
        Changed?.Invoke();
    }
}

/// <summary>A branch's condition: a checkbox ticked, or a radio group on one option.</summary>
public sealed record FormGate(FormBinding Binding, string? Option)
{
    public bool Open => Option == null ? Binding.On : Binding.Value == Option;
}

public abstract record FormItem;
public sealed record FormNote(string Text) : FormItem;
public sealed record FormOption(string Value, string Label, IReadOnlyList<FormItem> Items);
public sealed record FormRadio(FormBinding Binding, IReadOnlyList<FormOption> Options) : FormItem;
public sealed record FormCheck(FormBinding Binding, string Label, IReadOnlyList<FormItem> Items) : FormItem;
/// <summary>A text box; Kind = Text, Number or Multi (a script or XML).</summary>
public sealed record FormInput(FormBinding Binding, string Label, string Kind) : FormItem;
public sealed record FormSelect(FormBinding Binding, string Label) : FormItem;
public sealed record FormChecks(FormBinding Binding, string Label) : FormItem;
/// <summary>The account table: rows of name, display name, password (text boxes) and group (dropdown).</summary>
public sealed record FormAccounts(FormRows Rows) : FormItem;
/// <summary>His bloatware list: a checkbox per item, by name.</summary>
public sealed record FormBloatware(IReadOnlyList<(FormBinding Binding, string Label)> Items) : FormItem;
/// <summary>One phase's scripts: rows of type (dropdown) and script (text box).</summary>
public sealed record FormScripts(string Phase, string Label, FormRows Rows) : FormItem;
/// <summary>More components: rows of component-and-pass (dropdown) and its XML (text box).</summary>
public sealed record FormComponents(FormRows Rows) : FormItem;
public sealed record FormSection(string Title, IReadOnlyList<FormItem> Items);

/// <summary>Rows that grow (accounts, scripts, components): the used ones and one empty are shown; Add shows one more.</summary>
public sealed class FormRows(IReadOnlyList<IReadOnlyList<FormBinding>> rows, Func<IReadOnlyList<FormBinding>, bool> filled)
{
    public IReadOnlyList<IReadOnlyList<FormBinding>> Rows { get; } = rows;
    public int Shown { get; private set; } = 1;
    public event Action? Changed;

    public void Add() => Show(Math.Min(Shown + 1, Rows.Count));

    /// <summary>The used rows and one empty (Update-AkariUaFormAccounts / -Rows).</summary>
    public void Refresh()
    {
        var last = -1;
        for (var r = 0; r < Rows.Count; r++) if (filled(Rows[r])) last = r;
        Show(Math.Min(last + 2, Rows.Count));
    }

    private void Show(int n)
    {
        if (n == Shown) return;
        Shown = n;
        Changed?.Invoke();
    }
}

/// <summary>
/// The Unattend Generator's form (UI\UnattendForm.ps1, without WPF): src/UI/Unattend.psd1's Sections as items bound to
/// his fields. <see cref="Fields"/> = Get-AkariUaFormFields (only the picked branches, as his page sends them),
/// <see cref="Set"/> = Set-AkariUaFormFields, <see cref="Open"/> = what "Open file…" does with a file's fields.
/// </summary>
public sealed class UnattendForm
{
    private readonly List<FormBinding> _bindings = [];
    private readonly List<FormRows> _rowGroups = [];
    private readonly List<FormScripts> _scripts = [];

    public IReadOnlyList<FormSection> Sections { get; }
    public IReadOnlyList<FormBinding> Bindings => _bindings;
    public FormRows Accounts { get; private set; } = null!;
    public FormRows Components { get; private set; } = null!;
    public IReadOnlyList<FormScripts> Scripts => _scripts;

    private UnattendForm(PsHashtable spec)
    {
        Sections = [.. ((object?[])spec.Get("Sections")!).Cast<PsHashtable>()
            .Select(s => new FormSection(Text(s.Get("Title")), Items(s.Get("Items"), [])))];
    }

    public static UnattendForm Build(ISourceFiles files) => new(UnattendStart.Spec(files));

    /// <summary>The form as his fields: only the picked branches.</summary>
    public Dictionary<string, string[]> Fields()
    {
        var f = UnattendFields.New();
        foreach (var b in _bindings.Where(b => b.Counts))
            switch (b.Kind)
            {
                case FormKind.Radio when b.Value != null: f[b.Field] = [b.Value]; break;
                case FormKind.Check when b.On: f[b.Field] = ["true"]; break;
                case FormKind.Input: f[b.Field] = [b.Value ?? ""]; break;
                case FormKind.Select when b.Value != null: f[b.Field] = [b.Value]; break;
                case FormKind.Checks when b.Picked.Count > 0: f[b.Field] = [.. b.Picked]; break;
            }
        return f;
    }

    /// <summary>Fills the form: a checkbox is ticked only when its field says so; other fields keep their value when
    /// the fields lack them; a dropdown value its list lacks is added first (a keyboard of this PC).</summary>
    public void Set(IReadOnlyDictionary<string, string[]> fields)
    {
        foreach (var b in _bindings)
        {
            var has = fields.TryGetValue(b.Field, out var v);
            var first = has && v!.Length > 0 ? v[0] : "";
            switch (b.Kind)
            {
                case FormKind.Radio when has && b.Choices.Any(c => c.Id == first): b.Pick(first); break;
                case FormKind.Check: b.SetOn(has && first is "true" or "True" or "on"); break;
                case FormKind.Input when has: b.Pick(string.Join(" ", v!)); break;
                case FormKind.Select when has:
                    if (!b.Choices.Any(c => c.Id == first)) b.Choices.Insert(0, new FormChoice(first, first));
                    b.Pick(first);
                    break;
                case FormKind.Checks when has: b.SetPicked(v!); break;
            }
        }
        foreach (var g in _rowGroups) g.Refresh();
    }

    /// <summary>"Open file…": the start fields with the file's over them; a checkbox the file leaves out is off.</summary>
    public void Open(IReadOnlyDictionary<string, string[]> file, IReadOnlyDictionary<string, string[]> start)
    {
        var f = UnattendFields.Copy(start);
        foreach (var (k, v) in file) f[k] = v;
        Set(f);
        foreach (var b in _bindings.Where(b => b.Kind == FormKind.Check && !file.ContainsKey(b.Field))) b.SetOn(false);
    }

    /// <summary>The file wipes a disk by itself (a generated PE stage that partitions): saving asks first.</summary>
    public bool Wipes()
    {
        var f = Fields();
        return f.Get("PEMode") == "Generated" && f.Get("PartitionMode") is "Unattended" or "Custom";
    }

    // ---- building

    private FormBinding Bind(string field, FormKind kind, IReadOnlyList<FormGate> gates, IEnumerable<FormChoice>? choices = null, string? start = null)
    {
        var b = new FormBinding(field, kind, gates, choices?.ToList());
        if (start != null) b.Pick(start);
        _bindings.Add(b);
        return b;
    }

    private List<FormItem> Items(object? items, IReadOnlyList<FormGate> gates)
    {
        var list = new List<FormItem>();
        foreach (var it in (items as object?[] ?? []).Cast<PsHashtable>())
        {
            if (it.Get("Note") is { } note) list.Add(new FormNote(Text(note)));
            else if (it.Get("Radio") is { } radio)
            {
                var options = ((object?[])it.Get("Options")!).Cast<PsHashtable>().ToList();
                var b = Bind(Text(radio), FormKind.Radio, gates, options.Select(o => new FormChoice(Text(o.Get("Value")), Text(o.Get("Label")))));
                list.Add(new FormRadio(b, [.. options.Select(o => new FormOption(Text(o.Get("Value")), Text(o.Get("Label")),
                    Items(o.Get("Items"), [.. gates, new FormGate(b, Text(o.Get("Value")))])))]));
            }
            else if (it.Get("Check") is { } check)
            {
                var b = Bind(Text(check), FormKind.Check, gates);
                list.Add(new FormCheck(b, Text(it.Get("Label")), Items(it.Get("Items"), [.. gates, new FormGate(b, null)])));
            }
            else if (it.Get("Input") is { } input)
                list.Add(new FormInput(Bind(Text(input), FormKind.Input, gates, start: ""), Text(it.Get("Label")), Text(it.Get("Kind") ?? "Text")));
            else if (it.Get("Select") is { } select)
                list.Add(new FormSelect(Bind(Text(select), FormKind.Select, gates, Choices(it)), Text(it.Get("Label"))));
            else if (it.Get("Checks") is { } checks)
                list.Add(new FormChecks(Bind(Text(checks), FormKind.Checks, gates, Choices(it)), Text(it.Get("Label"))));
            else if (it.Get("Accounts") != null) list.Add(new FormAccounts(Accounts = AccountRows(gates)));
            else if (it.Get("Bloatware") != null)
                list.Add(new FormBloatware([.. UnattendFile.His.Bloatwares.Values
                    .OrderBy(b => b.DisplayName, StringComparer.CurrentCultureIgnoreCase)
                    .Select(b => (Bind(b.Id, FormKind.Check, gates), b.DisplayName))]));
            else if (it.Get("Scripts") is { } phase)
            {
                var s = new FormScripts(Text(phase), Text(it.Get("Label")), ScriptRows(Text(phase), gates));
                _scripts.Add(s);
                list.Add(s);
            }
            else if (it.Get("Components") != null) list.Add(new FormComponents(Components = ComponentRows(gates)));
        }
        return list;
    }

    private FormRows Rows(Func<int, IReadOnlyList<FormBinding>> row, Func<IReadOnlyList<FormBinding>, bool> filled)
    {
        var g = new FormRows([.. Enumerable.Range(0, 15).Select(row)], filled);
        _rowGroups.Add(g);
        return g;
    }

    private static readonly FormChoice[] Groups = [new("Administrators", "Administrators"), new("Users", "Users")];

    private FormRows AccountRows(IReadOnlyList<FormGate> gates) => Rows(
        r => [Bind($"AccountName{r}", FormKind.Input, gates, start: ""), Bind($"AccountDisplayName{r}", FormKind.Input, gates, start: ""),
              Bind($"AccountPassword{r}", FormKind.Input, gates, start: ""), Bind($"AccountGroup{r}", FormKind.Select, gates, Groups, "Users")],
        row => !string.IsNullOrEmpty(row[0].Value));

    private FormRows ScriptRows(string phase, IReadOnlyList<FormGate> gates)
    {
        FormChoice[] types = [new("Cmd", ".cmd"), new("Ps1", ".ps1"), new("Reg", ".reg"), .. phase == "DefaultUser" ? Array.Empty<FormChoice>() : [new("Vbs", ".vbs")]];
        return Rows(r => [Bind($"{phase}ScriptType{r}", FormKind.Select, gates, types, "Cmd"), Bind($"{phase}Script{r}", FormKind.Input, gates, start: "")],
            row => !string.IsNullOrEmpty(row[1].Value));
    }

    private FormRows ComponentRows(IReadOnlyList<FormGate> gates)
    {
        FormChoice[] items = [new("", "(none)"), .. DataList("Component").SelectMany(c =>
            c.GetProperty("Passes").EnumerateArray().Select(p => new FormChoice($"{c.GetProperty("Id").GetString()}-{p.GetString()}", $"{c.GetProperty("Id").GetString()} - {p.GetString()}")))];
        return Rows(r => [Bind($"Component{r}", FormKind.Select, gates, items, ""), Bind($"ComponentContent{r}", FormKind.Input, gates, start: "")],
            row => !string.IsNullOrEmpty(row[0].Value));
    }

    /// <summary>A dropdown's items: one of his data lists (Id, DisplayName; editions only the visible ones), in the
    /// file's order, or the item's own Options.</summary>
    private static IEnumerable<FormChoice> Choices(PsHashtable item)
    {
        if (item.Get("List") is { } list)
        {
            var name = Text(list);
            return DataList(name)
                .Where(e => name != "WindowsEdition" || e.GetProperty("Visible").GetBoolean())
                .Select(e => new FormChoice(e.GetProperty("Id").GetString()!, e.GetProperty("DisplayName").GetString()!)).ToList();
        }
        return ((object?[])item.Get("Options")!).Cast<PsHashtable>().Select(o => new FormChoice(Text(o.Get("Id")), Text(o.Get("Name")))).ToList();
    }

    private static readonly Dictionary<string, JsonElement[]> Lists = [];

    private static JsonElement[] DataList(string name)
    {
        lock (Lists)
        {
            if (!Lists.TryGetValue(name, out var l))
                Lists[name] = l = [.. JsonDocument.Parse(UnattendStart.Resource(name + ".json")).RootElement.EnumerateArray().Select(e => e.Clone())];
            return l;
        }
    }

    private static string Text(object? v) => PsSemantics.Text(v) ?? "";
}
