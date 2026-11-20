using AkariOS.App.Shell;
using AkariOS.Core;
using AkariOS.Core.Unattend;
using AkariOS.Framework.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.ViewModels;

/// <summary>One of his sections on Install USB: its title, glyph and whether it differs from the start
/// (Update-AkariUaSections: "Default" / "Changed from the default").</summary>
public sealed partial class UaSectionViewModel(FormSection section, string glyph, IReadOnlyList<string> fields) : ObservableObject
{
    public FormSection Section { get; } = section;
    public string Title => Section.Title;
    public string Glyph { get; } = glyph;

    /// <summary>The fields its controls set (its branches' too).</summary>
    public IReadOnlyList<string> Fields { get; } = fields;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(Status))]
    public partial bool Changed { get; set; }

    public string Status => Changed ? "Changed from the default" : "Default";
}

/// <summary>
/// Install USB (src/UI/Unattend.ps1, the prototype's PAGES.usb): Christoph Schneegans' form (Core's
/// <see cref="UnattendForm"/>) started from the defaults and this PC's language, region and time zone, kept for the
/// session; the drive bar (the setup USB found, Refresh, Save to a folder…, Save to USB); Open file… and Reset to
/// defaults; each section saying whether it differs from the start. Saving runs his generator: his check shows under
/// the drive bar; a file that wipes a disk, a drive without Windows setup, an existing file ask first. One per app (the
/// ISO Builder asks it for its answer file).
/// </summary>
public sealed partial class UnattendViewModel : ObservableObject
{
    private const string Title = "Install USB";

    /// <summary>$AkariUaSectionIcons in Segoe Fluent Icons, in his section order.</summary>
    public static IReadOnlyList<string> SectionGlyphs { get; } =
    [
        "", "", "", "", "", "", "", "", "", "", "", "",
        "", "", "", "", "", "", "", "", "", "", "", "",
        "", "", "", "", "",
    ];

    private readonly Engine _engine;
    private readonly IDialogService _dialogs;
    private readonly IFilePicker _picker;
    private readonly IShellOpen _open;
    private readonly ShellState _shell;
    private readonly ISetupDrives _drives;
    private readonly IPcRegion? _region;
    private UnattendForm? _form;
    private IReadOnlyList<UaSectionViewModel>? _sections;
    private Dictionary<string, string[]>? _startFields;
    private IReadOnlyList<SetupDrive> _driveList = [];
    private bool _syncing;

    public UnattendViewModel(Engine engine, IDialogService dialogs, IFilePicker picker, IShellOpen open, ShellState shell, ISetupDrives drives, IPcRegion? region)
    {
        (_engine, _dialogs, _picker, _open, _shell, _drives, _region) = (engine, dialogs, picker, open, shell, drives, region);
    }

    /// <summary>His form, built once (its values are what the page shows).</summary>
    public UnattendForm Form
    {
        get
        {
            if (_form is not null) return _form;
            _form = UnattendForm.Build(_engine.Files);
            foreach (var b in _form.Bindings) b.Changed += () => { if (!_syncing) UpdateSections(); };
            return _form;
        }
    }

    public IReadOnlyList<UaSectionViewModel> Sections => _sections ??=
        [.. Form.Sections.Select((s, i) => new UaSectionViewModel(s, i < SectionGlyphs.Count ? SectionGlyphs[i] : CategoryGlyphs.Settings, [.. FieldsOf(s.Items).Distinct()]))];

    /// <summary>His check, or why the file wasn't saved, under the drive bar ("" = none).</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasError))]
    public partial string Error { get; private set; } = "";

    public bool HasError => Error.Length > 0;

    /// <summary>The drives as shown, Windows setup ones first.</summary>
    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasDriveChoice))]
    public partial IReadOnlyList<string> DriveNames { get; private set; } = [];

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(DriveName), nameof(DriveNote), nameof(CanSaveToUsb))]
    public partial int DriveIndex { get; set; } = -1;

    public bool HasDriveChoice => DriveNames.Count > 1;
    public bool CanSaveToUsb => Drive is not null;
    public string DriveName => Drive is { } d ? SetupDrives.Display(d) : "No Windows setup USB found";
    public string DriveNote => Drive is null ? "Plug one in, then refresh" : "The file goes to the root of the drive";

    private SetupDrive? Drive => DriveIndex >= 0 && DriveIndex < _driveList.Count ? _driveList[DriveIndex] : null;

    /// <summary>The page opened: the form starts (once), the drives are read (every time).</summary>
    public void Shown()
    {
        Started();
        RefreshDrives();
    }

    private void Started()
    {
        if (_startFields is not null) return;
        SetStart();
    }

    // Set-AkariUnattendStartFields: the form on its start, which each section's line compares with
    private void SetStart()
    {
        _syncing = true;
        try { Form.Set(Start()); }
        finally { _syncing = false; }
        _startFields = Form.Fields();
        UpdateSections();
    }

    /// <summary>The form's starting fields: the defaults, the samples, this PC's language, region and time zone (also
    /// the ISO Builder's "A local account").</summary>
    public Dictionary<string, string[]> Start()
    {
        PcRegion? pc = null;
        try { pc = _region?.Read(); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or System.Security.SecurityException)
        {
            _engine.Log.WriteFile($"Warning: Install USB: this PC's language not read ({e.Message})");
        }
        return UnattendStart.Fields(_engine.Files, pc ?? new PcRegion(null, null, null, null, null));
    }

    private void UpdateSections()
    {
        if (_startFields is null) return;
        var now = Form.Fields();
        foreach (var s in Sections)
            s.Changed = s.Fields.Any(f => Joined(now, f) != Joined(_startFields, f));
    }

    private static string Joined(Dictionary<string, string[]> fields, string f) => fields.TryGetValue(f, out var v) ? string.Join("|", v) : "";

    /// <summary>The fields a section's items set, its branches and rows included.</summary>
    public static IEnumerable<string> FieldsOf(IEnumerable<FormItem> items)
    {
        foreach (var item in items)
            switch (item)
            {
                case FormRadio r:
                    yield return r.Binding.Field;
                    foreach (var f in r.Options.SelectMany(o => FieldsOf(o.Items))) yield return f;
                    break;
                case FormCheck c:
                    yield return c.Binding.Field;
                    foreach (var f in FieldsOf(c.Items)) yield return f;
                    break;
                case FormInput i: yield return i.Binding.Field; break;
                case FormSelect s: yield return s.Binding.Field; break;
                case FormChecks m: yield return m.Binding.Field; break;
                case FormAccounts a: foreach (var b in a.Rows.Rows.SelectMany(r => r)) yield return b.Field; break;
                case FormBloatware b: foreach (var (x, _) in b.Items) yield return x.Field; break;
                case FormScripts s: foreach (var b in s.Rows.Rows.SelectMany(r => r)) yield return b.Field; break;
                case FormComponents c: foreach (var b in c.Rows.Rows.SelectMany(r => r)) yield return b.Field; break;
            }
    }

    // ---- the drive bar

    /// <summary>Update-AkariUnattendDrives: drives with Windows setup first (and picked).</summary>
    [RelayCommand]
    public void RefreshDrives()
    {
        try { _driveList = SetupDrives.Ordered(_drives.All()); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            _driveList = [];
            _engine.Log.Write($"Warning: drives not read ({e.Message})");
        }
        DriveNames = [.. _driveList.Select(SetupDrives.Display)];
        DriveIndex = -1;
        DriveIndex = _driveList.Count > 0 ? 0 : -1;
    }

    // ---- the command bar

    /// <summary>"Open file…": a file made on Schneegans' site or by AkariOS (its first comment holds the choices).</summary>
    [RelayCommand]
    public async Task OpenAsync()
    {
        if (await _picker.OpenXmlAsync() is not { } path) return;
        Started();
        Dictionary<string, string[]>? fields = null;
        try { fields = UnattendQuery.FromXml(File.ReadAllText(path)); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { _engine.Log.Write($"Warning: {path} could not be read ({e.Message})"); }
        if (fields is null)
        {
            await _dialogs.ShowInfoAsync(Title, "This file wasn't made by AkariOS or Schneegans' generator, so its choices can't be read back.");
            return;
        }
        Form.Open(fields, Start());
        Error = "";
        _engine.Log.Write($"Install USB: opened {path}");
        _shell.Toast($"Opened {Path.GetFileName(path)}", "Its choices are in the form.", InfoBarSeverity.Informational);
    }

    /// <summary>"Reset to defaults": asked, then every section back to the start.</summary>
    [RelayCommand]
    public async Task ResetAsync()
    {
        if (!await _dialogs.ConfirmAsync("Reset every section?", "The form goes back to the defaults and this PC's language, keyboard, region and time zone.", "Reset")) return;
        SetStart();
        Error = "";
    }

    // ---- saving

    /// <summary>"Save to USB": at the root of the picked drive; a drive without Windows setup, or a file already
    /// there, asks first.</summary>
    [RelayCommand]
    public async Task SaveToUsbAsync()
    {
        if (Bytes() is not { } bytes) return;
        if (Drive is not { } d)
        {
            Error = "No USB drive found: plug one in and press Refresh, or save to a folder.";
            return;
        }
        if (!await ConfirmWipeAsync()) return;
        if (!d.Setup && !await _dialogs.ConfirmAsync(Title, $"{d.Root} has no Windows setup on it (no sources\\install.wim or .esd).\n\nSave the file there anyway?", "Save anyway")) return;
        if (UnattendSave.Exists(d.Root) && !await _dialogs.ConfirmAsync(Title, $"{d.Root} already has an autounattend.xml.\n\nReplace it?", "Replace")) return;
        SaveTo(bytes, d.Root);
    }

    /// <summary>"Save to a folder…": anywhere (Ventoy, Rufus, ahead of time).</summary>
    [RelayCommand]
    public async Task SaveToFolderAsync()
    {
        if (Bytes() is not { } bytes) return;
        if (!await ConfirmWipeAsync()) return;
        if (await _picker.FolderAsync() is not { } folder) return;
        if (UnattendSave.Exists(folder) && !await _dialogs.ConfirmAsync(Title, "This folder already has an autounattend.xml.\n\nReplace it?", "Replace")) return;
        SaveTo(bytes, folder);
    }

    /// <summary>The ISO Builder's "The Unattend Generator's choices": the form started if its page never opened, the
    /// disk-wipe question first. Bytes null with an error = his check refused it; both null = cancelled.</summary>
    public async Task<(byte[]? Bytes, string? Error)> IsoAnswerAsync()
    {
        Started();
        if (!await ConfirmWipeAsync()) return (null, null);
        try { return (UnattendFile.Make(Form.Fields()), null); }
        catch (UnattendException e) { return (null, e.Message); }
    }

    // the file for the form, or null with his check shown
    private byte[]? Bytes()
    {
        Started();
        Error = "";
        try { return UnattendFile.Make(Form.Fields()); }
        catch (UnattendException e)
        {
            Error = e.Message;
            return null;
        }
    }

    // a file that partitions a disk by itself: said before it is written
    private async Task<bool> ConfirmWipeAsync() => !Form.Wipes() || await _dialogs.ConfirmAsync(Title,
        "This file wipes a disk without asking (Windows PE stage, partitioning). Only use the USB on a PC whose disk you mean to erase.\n\nSave it anyway?",
        "Save anyway");

    private void SaveTo(byte[] bytes, string folder)
    {
        try
        {
            var path = UnattendSave.Save(bytes, folder);
            _engine.Log.Write($"Install USB: saved {path}");
            _shell.Toast("autounattend.xml saved", path);
            _open.Folder(folder);
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            Error = $"Not saved: {e.Message}";
            _engine.Log.Write($"Error: Install USB: not saved ({e.Message})");
        }
    }
}
