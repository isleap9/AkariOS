using System.IO;
using System.Windows;
using System.Windows.Controls;
using AkariOS.App.Look;
using AkariOS.App.Shell;
using AkariOS.Core.Unattend;

namespace AkariOS.App.Pages;

/// <summary>
/// The Unattend Generator (src/UI/Unattend.ps1; its tab and Home tile, full page, Back leads Home): Schneegans' form on
/// one long page (UnattendFormView), then Save: autounattend.xml (his vendored generator, AkariOS.Core/Unattend) to a
/// Windows install USB or a folder. Built once per run: it keeps what was typed. Open file… reads a file made by his
/// site or by Akari (its first comment holds the choices); Reset to defaults starts again from the defaults and this PC.
/// </summary>
public sealed class UnattendPage(AppServices s)
{
    private const string Title = "Unattend Generator";
    private UnattendForm? _form;
    private FrameworkElement? _view;
    private readonly ComboBox _drive = new() { MinWidth = 280, Margin = new Thickness(0, 0, 8, 0) };
    private readonly TextBlock _error = Parts.Text("", 13, "Bad");
    private IReadOnlyList<SetupDrive> _drives = [];

    public UnattendForm Form => _form ??= UnattendForm.Build(s.Engine.Files);

    /// <summary>The problem shown under Save ("" = none).</summary>
    public string Error => _error.Text;

    /// <summary>The drive list as shown (Windows setup drives first) and the picked one.</summary>
    public IReadOnlyList<string> DriveNames => [.. _drives.Select(SetupDrives.Display)];
    public int DriveIndex { get => _drive.SelectedIndex; set => _drive.SelectedIndex = value; }

    public UIElement Build()
    {
        if (_view != null) return _view;
        Form.Set(Start());
        var stack = new StackPanel();
        var bar = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 12) };
        bar.Children.Add(Parts.Button("Open file…", click: Open));
        bar.Children.Add(Parts.Button("Reset to defaults", click: Reset));
        stack.Children.Add(bar);
        UnattendFormView.AddSections(stack, Form);

        var (card, body) = Parts.Card("Save");
        _drive.SetResourceReference(FrameworkElement.StyleProperty, "Combo");
        var drives = new StackPanel { Orientation = Orientation.Horizontal };
        drives.Children.Add(_drive);
        drives.Children.Add(Parts.Button("Refresh", click: RefreshDrives));
        body.Children.Add(drives);
        var buttons = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 12, 0, 0) };
        buttons.Children.Add(Parts.Button("Save to USB", "Accent", SaveToUsb));
        buttons.Children.Add(Parts.Button("Save to a folder…", click: SaveToFolder));
        body.Children.Add(buttons);
        _error.Margin = new Thickness(0, 10, 0, 0);
        body.Children.Add(_error);
        stack.Children.Add(card);

        var back = Parts.Button("Back", click: () => s.Shell.Open("Home"));
        back.HorizontalAlignment = HorizontalAlignment.Left;
        back.MinWidth = 96;
        stack.Children.Add(back);
        RefreshDrives();

        // one readable column on the left, at most 860 px wide
        var column = new Grid();
        column.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star), MaxWidth = 860 });
        column.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(0, GridUnitType.Auto) });
        column.Children.Add(stack);
        return _view = column;
    }

    /// <summary>The form's starting fields: the defaults, the samples, this PC's language, region and time zone.</summary>
    private Dictionary<string, string[]> Start()
    {
        PcRegion? pc = null;
        try { pc = s.Region?.Read(); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or System.Security.SecurityException) { s.Log.WriteFile($"Warning: Unattend Generator: this PC's language not read ({e.Message})"); }
        return UnattendStart.Fields(s.Engine.Files, pc ?? new PcRegion(null, null, null, null, null));
    }

    /// <summary>The drive list: drives with Windows setup first (and picked).</summary>
    public void RefreshDrives()
    {
        try { _drives = SetupDrives.Ordered(s.Drives?.All() ?? []); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { _drives = []; s.Log.Write($"Warning: drives not read ({e.Message})"); }
        _drive.ItemsSource = DriveNames;
        _drive.SelectedIndex = _drives.Count > 0 ? 0 : -1;
    }

    /// <summary>"Open file…": a file made on Schneegans' site or by Akari.</summary>
    public void Open()
    {
        if (s.Picker?.OpenXml() is not { } path) return;
        Dictionary<string, string[]>? fields = null;
        try { fields = UnattendQuery.FromXml(File.ReadAllText(path)); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { s.Log.Write($"Warning: {path} could not be read ({e.Message})"); }
        if (fields == null)
        {
            s.Dialogs?.Message("This file wasn't made by Akari or Schneegans' generator, so its choices can't be read back.", "Warning", Title);
            return;
        }
        Form.Open(fields, Start());
        _error.Text = "";
        s.Log.Write($"Unattend Generator: opened {path}");
    }

    public void Reset()
    {
        Form.Set(Start());
        _error.Text = "";
    }

    /// <summary>"Save to USB": at the root of the picked drive; a drive without Windows setup, or a file already
    /// there, asks first.</summary>
    public void SaveToUsb()
    {
        if (Bytes() is not { } bytes) return;
        if (_drive.SelectedIndex < 0 || _drive.SelectedIndex >= _drives.Count)
        {
            _error.Text = "No USB drive found: plug one in and press Refresh, or save to a folder.";
            return;
        }
        var d = _drives[_drive.SelectedIndex];
        if (!ConfirmWipe()) return;
        if (!d.Setup && s.Dialogs?.Confirm($"{d.Root} has no Windows setup on it (no sources\\install.wim or .esd).\n\nSave the file there anyway?", "Save anyway", "Cancel", "Warning", Title) != true) return;
        if (UnattendSave.Exists(d.Root) && s.Dialogs?.Confirm($"{d.Root} already has an autounattend.xml.\n\nReplace it?", "Replace", "Cancel", "Question", Title) != true) return;
        SaveTo(bytes, d.Root);
    }

    /// <summary>"Save to a folder…": anywhere (Ventoy, Rufus, ahead of time).</summary>
    public void SaveToFolder()
    {
        if (Bytes() is not { } bytes) return;
        if (!ConfirmWipe()) return;
        if (s.Picker?.Folder("Where should autounattend.xml go?") is not { } folder) return;
        if (UnattendSave.Exists(folder) && s.Dialogs?.Confirm("This folder already has an autounattend.xml.\n\nReplace it?", "Replace", "Cancel", "Question", Title) != true) return;
        SaveTo(bytes, folder);
    }

    /// <summary>The file for the form, or null with his check shown under Save.</summary>
    private byte[]? Bytes()
    {
        _error.Text = "";
        try { return UnattendFile.Make(Form.Fields()); }
        catch (UnattendException e) { _error.Text = e.Message; return null; }
    }

    /// <summary>A file that partitions a disk by itself: said before it is written.</summary>
    private bool ConfirmWipe() => !Form.Wipes() || s.Dialogs?.Confirm(
        "This file wipes a disk without asking (Windows PE stage, partitioning). Only use the USB on a PC whose disk you mean to erase.\n\nSave it anyway?",
        "Save anyway", "Cancel", "Warning", Title) == true;

    private void SaveTo(byte[] bytes, string folder)
    {
        try
        {
            var path = UnattendSave.Save(bytes, folder);
            s.Log.Write($"Unattend Generator: saved {path}");
            s.Open.Folder(folder);
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            _error.Text = $"Not saved: {e.Message}";
            s.Log.Write($"Error: Unattend Generator not saved ({e.Message})");
        }
    }
}
