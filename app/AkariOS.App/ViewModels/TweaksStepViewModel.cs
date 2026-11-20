using System.Collections.ObjectModel;
using AkariOS.App.Shell;
using AkariOS.Core;
using AkariOS.Core.Data;
using AkariOS.Core.Presets;
using AkariOS.Core.Registry;
using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;
using AkariOS.Framework.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI.Xaml;

namespace AkariOS.App.ViewModels;

/// <summary>
/// One row of the Guided Tweaks step (New-AkariTweakRow): a checkbox (Toggle, Action) or a dropdown starting on "No
/// change" (Choice; an Editable one takes a typed number too); Risk, restart and an unread State marked; the
/// description and State in its tooltip. A pick goes to the step (<c>picked</c>), which asks first when needed and
/// writes it into the Selection; the control is set back with no pick coming of it.
/// </summary>
public sealed partial class TweakRowViewModel : ObservableObject
{
    private readonly Action<TweakRowViewModel, object> _picked;
    private bool _muted;
    private bool _isChecked;
    private object? _selectedChoice;

    public TweakRowViewModel(Tweak t, TweakState state, object? current, object? windowsDefault, Action<TweakRowViewModel, object> picked)
    {
        (Tweak, State, Current, WindowsDefault, _picked) = (t, state, current, windowsDefault, picked);
        Choices.Add(new ChoiceItem("No change", Selection.None));
        foreach (var c in t.Choices)
        {
            var label = c.Label.Length > 0 ? c.Label : $"{c.Value}";
            if (RegistryEngine.Matches(c.Value, t.Recommended)) label += " (Recommended)";
            else if (RegistryEngine.Matches(c.Value, windowsDefault)) label += " (Windows default)";
            Choices.Add(new ChoiceItem(label, c.Value));
        }
        _selectedChoice = Choices[0];
    }

    public Tweak Tweak { get; }
    public TweakState State { get; }
    public object? Current { get; }
    public object? WindowsDefault { get; }

    /// <summary>Where the row started (Optimized / None, or a Choice value) and what a Choice row shows now.</summary>
    public object Initial { get; set; } = Selection.None;
    public object Shown { get; set; } = Selection.None;

    public string Name => Tweak.Name;
    public bool IsAkariOS => Tweak.AkariOS;

    /// <summary>" (AkariOS)" after the name: part of the AkariOS setup.</summary>
    public string AkariOSTag => Tweak.AkariOS ? " (AkariOS)" : "";
    public string Tip => Selection.RowTip(Tweak, State);
    public bool IsCheck => Tweak.Kind != TweakKind.Choice;
    public bool IsChoice => Tweak.Kind == TweakKind.Choice;
    public bool IsEditable => Tweak.Editable;
    public bool IsCaution => Tweak.Risk == Risk.Caution;
    public bool IsAdvanced => Tweak.Risk == Risk.Advanced;
    public bool Reboots => Tweak.Reboot;
    public bool StateUnread => Tweak.Kind != TweakKind.Action && State is TweakState.Custom or TweakState.Unknown;
    public string StateTip => State == TweakState.Custom ? "Custom value" : "State unknown";

    /// <summary>"No change" first, then the values (a typed one added at the end).</summary>
    public ObservableCollection<ChoiceItem> Choices { get; } = [];

    [ObservableProperty]
    public partial Visibility Shows { get; set; } = Visibility.Visible;

    public bool IsShown => Shows == Visibility.Visible;

    public bool IsChecked
    {
        get => _isChecked;
        set
        {
            if (!SetProperty(ref _isChecked, value) || _muted) return;
            _picked(this, Selection.CheckTarget(value, Initial));
        }
    }

    public object? SelectedChoice
    {
        get => _selectedChoice;
        set
        {
            if (!SetProperty(ref _selectedChoice, value) || _muted || value is not ChoiceItem { Value: { } v }) return;
            _picked(this, v);
        }
    }

    /// <summary>A number typed into an Editable Choice (Get-AkariComboValue): one of its values is picked, another is
    /// added as "n (typed)"; text that isn't a number puts the row back. False: not taken.</summary>
    public bool Type(string text)
    {
        if (text.Trim().Length == 0) { SelectedChoice = Choices[0]; return true; }
        if (Selection.ParseNumber(text) is not { } n) { SetControl(Shown); return false; }
        SelectedChoice = Item(n);
        return true;
    }

    private ChoiceItem Item(object value)
    {
        var item = Choices.Skip(1).FirstOrDefault(i => RegistryEngine.Matches(i.Value, value));
        if (item is not null) return item;
        // one typed value at a time
        if (Choices.Count > Tweak.Choices.Count + 1) Choices.RemoveAt(Choices.Count - 1);
        item = new ChoiceItem($"{value} (typed)", value);
        Choices.Add(item);
        return item;
    }

    /// <summary>Puts the control on a target (Set-AkariRowControl): Optimized = checked, a Choice value, None.</summary>
    public void SetControl(object target)
    {
        _muted = true;
        try
        {
            if (IsChoice)
                SelectedChoice = target as string == Selection.None ? Choices[0]
                    : Choices.Skip(1).FirstOrDefault(i => RegistryEngine.Matches(i.Value, target)) ?? (IsEditable ? Item(target) : Choices[0]);
            else
            {
                // through the property: a box the user just ticked goes back when the pick didn't happen
                _isChecked = target as string != Selection.Optimized;
                IsChecked = !_isChecked;
            }
        }
        finally { _muted = false; }
    }
}

/// <summary>A Category card of the Tweaks step: its name, glyph, rows and "n of m".</summary>
public sealed partial class TweakCategoryViewModel(string name, string glyph, IReadOnlyList<TweakRowViewModel> rows) : ObservableObject
{
    public string Name { get; } = name;
    public string Glyph { get; } = glyph;
    public IReadOnlyList<TweakRowViewModel> Rows { get; } = rows;

    /// <summary>A Choice counts 2 (Get-AkariMasonry).</summary>
    public int Size => Rows.Sum(r => r.IsChoice ? 2 : 1);

    [ObservableProperty]
    public partial Visibility Shows { get; set; } = Visibility.Visible;

    [ObservableProperty]
    public partial string CountText { get; set; } = "";
}

/// <summary>A Section of the Tweaks step: its heading and its Category cards in two or three masonry columns.</summary>
public sealed partial class TweakSectionViewModel(string section, string header, IReadOnlyList<TweakCategoryViewModel> categories) : ObservableObject
{
    public string Section { get; } = section;
    public string Header { get; } = header;
    public IReadOnlyList<TweakCategoryViewModel> Categories { get; } = categories;

    [ObservableProperty]
    public partial IReadOnlyList<TweakCategoryViewModel> Column0 { get; private set; } = [];

    [ObservableProperty]
    public partial IReadOnlyList<TweakCategoryViewModel> Column1 { get; private set; } = [];

    [ObservableProperty]
    public partial IReadOnlyList<TweakCategoryViewModel> Column2 { get; private set; } = [];

    /// <summary>The third column's width (0 with two columns).</summary>
    [ObservableProperty]
    public partial GridLength ThirdWidth { get; private set; } = new(1, GridUnitType.Star);

    [ObservableProperty]
    public partial Visibility Shows { get; set; } = Visibility.Visible;

    /// <summary>Set-AkariTweaksColumns: each card in the shortest column so far (only the cards shown count).</summary>
    public void Lay(int columns)
    {
        var shown = Categories.Where(c => c.Shows == Visibility.Visible).ToList();
        var at = Selection.Masonry(shown.Select(c => c.Size).ToList(), columns);
        var cols = Enumerable.Range(0, 3).Select(i => shown.Where((_, n) => at[n] == i).ToList()).ToList();
        (Column0, Column1, Column2) = (cols[0], cols[1], cols[2]);
        ThirdWidth = columns == 3 ? new GridLength(1, GridUnitType.Star) : new GridLength(0);
    }
}

/// <summary>
/// The Guided Tweaks step (Get-AkariTweaksView, after Win11Debloat's System Tweaks): a toolbar (Quick select, Clear
/// selection, Show current state, a filter), then per Section a heading and Category cards. Every State is read once
/// in the background before the rows are made. The rows write into the Selection; nothing changes on the PC here.
/// </summary>
public sealed partial class TweaksStepViewModel : ObservableObject
{
    private readonly Engine _engine;
    private readonly IBackground _background;
    private readonly IDialogService _dialogs;
    private readonly ITextDialog _text;
    private readonly IDictionary<string, Pending> _sel;
    private readonly Action _changed;
    private readonly Action<Preset, IReadOnlyList<string>>? _pickApps;
    private readonly Dictionary<string, TweakRowViewModel> _rows = [];
    private Preset? _pending;
    private bool _useState = true;
    private string _query = "";
    private int _columns = 3;

    public TweaksStepViewModel(Engine engine, IBackground background, IDialogService dialogs, ITextDialog text, IDictionary<string, Pending> sel,
        Action changed, Action<Preset, IReadOnlyList<string>>? pickApps = null)
    {
        (_engine, _background, _dialogs, _text, _sel, _changed, _pickApps) = (engine, background, dialogs, text, sel, changed, pickApps);
    }

    /// <summary>Until every State is read.</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(IsBuilt))]
    public partial bool IsReading { get; private set; }

    public bool IsBuilt => !IsReading && Sections.Count > 0;

    public ObservableCollection<TweakSectionViewModel> Sections { get; } = [];

    /// <summary>The rows by Tweak id, once built.</summary>
    public IReadOnlyDictionary<string, TweakRowViewModel> Rows => _rows;

    /// <summary>"Show current state": rows start on the State read from this PC.</summary>
    public bool UseState
    {
        get => _useState;
        set
        {
            if (SetProperty(ref _useState, value)) Reset();
        }
    }

    /// <summary>The filter: rows whose name or description don't have it hide, then empty cards and Sections.</summary>
    public string Query
    {
        get => _query;
        set
        {
            if (SetProperty(ref _query, value ?? "")) Filter();
        }
    }

    /// <summary>Starts reading the States (once).</summary>
    public void Ensure()
    {
        if (IsReading || Sections.Count > 0) return;
        IsReading = true;
        var groups = Selection.StepGroups(_engine.Loaded.Tweaks, _engine.System);
        var tweaks = groups.SelectMany(g => g.Categories).SelectMany(c => c.Ids).Select(id => _engine.Loaded.Find(id)!).ToList();
        _background.Run(() => tweaks.ToDictionary(t => t.Id, Read), r =>
        {
            Build(groups, r as Dictionary<string, StateRead> ?? []);
            IsReading = false;
            if (_pending is { } p) { _pending = null; QuickSelect(p); }
        });
    }

    private sealed record StateRead(TweakState State, object? Current);

    private StateRead Read(Tweak t)
    {
        var state = TweakState.Unknown;
        try { state = _engine.States.Of(t); } catch (Exception) { }
        object? current = null;
        if (t.Kind == TweakKind.Choice) try { current = _engine.States.ChoiceValue(t); } catch (Exception) { }
        return new StateRead(state, current);
    }

    private void Build(IReadOnlyList<StepSection> groups, Dictionary<string, StateRead> states)
    {
        foreach (var g in groups)
        {
            var cats = g.Categories.Select(c => new TweakCategoryViewModel(c.Name, CategoryGlyphs.Of(c.Name), c.Ids.Select(id =>
            {
                var t = _engine.Loaded.Find(id)!;
                var st = states.GetValueOrDefault(id) ?? new StateRead(TweakState.Unknown, null);
                return _rows[id] = new TweakRowViewModel(t, st.State, st.Current, _engine.States.DefaultFor(t), (row, target) => _background.Post(() => _ = PickAsync(row, target)));
            }).ToList())).ToList();
            Sections.Add(new TweakSectionViewModel(g.Section, g.Header, cats));
        }
        Reset();
        Filter();
    }

    /// <summary>Two or three columns, by the view's width (Win11Debloat folds its third column under 900 px).</summary>
    public void SetColumns(int columns)
    {
        _columns = columns;
        foreach (var s in Sections) s.Lay(columns);
    }

    // Step-AkariCheck / Set-AkariChoiceTarget: asked first when needed, then into the Selection
    private async Task PickAsync(TweakRowViewModel row, object target)
    {
        var t = row.Tweak;
        if (row.IsChoice)
        {
            var none = target as string == Selection.None;
            var same = none ? row.Shown as string == Selection.None : row.Shown as string != Selection.None && RegistryEngine.Matches(target, row.Shown);
            if (same) return;
            if (!none && Selection.ConfirmText(t, target, row.WindowsDefault) is { } q && !await _dialogs.ConfirmAsync(t.Name, q, "Continue"))
            {
                row.SetControl(row.Shown);
                return;
            }
            row.Shown = target;
            Selection.SetPending(_sel, t, row.State, target, row.Current, row.WindowsDefault);
        }
        else
        {
            if (Selection.ConfirmText(t, target, row.WindowsDefault) is { } q && !await _dialogs.ConfirmAsync(t.Name, q, "Continue"))
            {
                row.SetControl(row.IsChecked ? Selection.None : Selection.Optimized);
                return;
            }
            Selection.SetPending(_sel, t, row.State, target, null, row.WindowsDefault);
        }
        Counts();
        _changed();
    }

    /// <summary>Reset-AkariTweakRows: every row back where it starts, its change out of the Selection, and the
    /// changes a preset brought for Tweaks with no row here.</summary>
    [RelayCommand]
    public void Reset()
    {
        foreach (var row in _rows.Values)
        {
            row.Initial = row.Shown = Selection.RowStart(row.Tweak, row.State, row.Current, UseState);
            row.SetControl(row.Initial);
            _sel.Remove(row.Tweak.Id);
        }
        foreach (var id in _sel.Where(p => p.Value.Hidden && _engine.Find(p.Key) is not { Section: "Apps" }).Select(p => p.Key).ToList()) _sel.Remove(id);
        Counts();
        _changed();
    }

    // Update-AkariTweakCounts: "n of m" picked per card
    private void Counts()
    {
        foreach (var c in Sections.SelectMany(s => s.Categories))
            c.CountText = $"{c.Rows.Count(r => _sel.ContainsKey(r.Tweak.Id))} of {c.Rows.Count}";
    }

    private void Filter()
    {
        var q = _query.Trim();
        foreach (var row in _rows.Values)
            row.Shows = q.Length == 0 || PsSemantics.Like($"{row.Tweak.Name} {row.Tweak.Description}", $"*{q}*") ? Visibility.Visible : Visibility.Collapsed;
        foreach (var s in Sections)
        {
            foreach (var c in s.Categories) c.Shows = c.Rows.Any(r => r.IsShown) ? Visibility.Visible : Visibility.Collapsed;
            s.Shows = s.Categories.Any(c => c.Shows == Visibility.Visible) ? Visibility.Visible : Visibility.Collapsed;
        }
        SetColumns(_columns);
    }

    // ---- Quick select

    /// <summary>The presets Quick select lists: built-in, Last used, the user's.</summary>
    public IReadOnlyList<Preset> Presets()
    {
        var all = _engine.Presets.All();
        return [.. all.Where(p => p.Builtin), .. _engine.Presets.LastUsed() is { } last ? [last] : Array.Empty<Preset>(), .. all.Where(p => !p.Builtin)];
    }

    /// <summary>A preset's label in the menu.</summary>
    public static string PresetLabel(Preset p) => p.Builtin && p.Name == "AkariOS" ? "AkariOS (recommended)" : p.Name;

    /// <summary>Set-AkariQuickSelect: every row back where it starts, then the preset's changes picked. A Toggle or
    /// Choice with no row here (Guided = $false) is picked all the same, marked Hidden; the apps go to the Apps step.</summary>
    public void QuickSelect(Preset preset)
    {
        Ensure();
        if (IsReading) { _pending = preset; return; }
        var plan = PresetStore.Resolve(preset, _engine.Loaded.Tweaks);
        Reset();
        foreach (var id in _sel.Where(p => _engine.Find(p.Key) is not { Section: "Apps" }).Select(p => p.Key).ToList()) _sel.Remove(id);
        var missing = 0;
        foreach (var i in plan.Items)
        {
            var t = _engine.Find(i.Id);
            if (t is null) { missing++; continue; }
            if (t.Section == "Apps") continue;
            var def = _engine.States.DefaultFor(t);
            object? target = i.Mode == TweakMode.Revert ? (t.Kind == TweakKind.Choice ? def : Selection.Default)
                : t.Kind == TweakKind.Choice ? i.Value ?? t.Recommended : Selection.Optimized;
            if (_rows.TryGetValue(i.Id, out var row))
            {
                row.SetControl(target is null || target as string == Selection.Default ? Selection.None : target);
                if (t.Kind == TweakKind.Choice) row.Shown = target ?? Selection.None;
                Selection.SetPending(_sel, t, row.State, target, row.Current, def);
            }
            else if (PresetStore.ExportTweaks([t], _engine.System).Count > 0)
            {
                // Set-AkariHiddenPending: its State read now
                var r = Read(t);
                Selection.SetPending(_sel, t, r.State, target, r.Current, def);
                if (_sel.TryGetValue(t.Id, out var p)) _sel[t.Id] = p with { Hidden = true };
            }
            else missing++;
        }
        Counts();
        _changed();
        _pickApps?.Invoke(preset, plan.Items.Select(i => i.Id).ToList());
        var unknown = missing + plan.Unknown.Count;
        _engine.Log.Write($"Quick select: {preset.Name}, {_sel.Count} changes{(unknown > 0 ? $" ({unknown} not on this PC or not shown here)" : "")}");
    }

    /// <summary>Save-AkariQuickSelect: the Selection as a user preset, named by the user.</summary>
    [RelayCommand]
    public async Task SavePresetAsync()
    {
        if (_sel.Count == 0) { await _dialogs.ShowInfoAsync("Save as preset", "Pick some changes first, then save them as a preset."); return; }
        if (await _text.AskAsync("Save as preset", "A name for this preset:", "Save") is not { Length: > 0 } name) return;
        var path = _engine.Presets.Save(name, Selection.PlanItems(_sel.Values), "Saved from Install AkariOS");
        _engine.Log.Write($"Preset saved: {path}");
    }
}
