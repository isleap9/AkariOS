using System.Collections.ObjectModel;
using AkariOS.Core;
using AkariOS.Core.Pipeline;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.UI.Xaml;

namespace AkariOS.App.ViewModels;

/// <summary>One selectable Windows edition inside the source ISO's install.wim.</summary>
public partial class EditionItem : ObservableObject
{
    public int Index { get; init; }
    public string Name { get; init; } = "";

    [ObservableProperty]
    public partial bool IsSelected { get; set; } = true;

    public EditionItem(int index, string name)
    {
        Index = index;
        Name = name;
    }
}

/// <summary>An ISO added to the sidebar via drag-drop or browse.</summary>
public partial class IsoItem : ObservableObject
{
    public string Path { get; init; } = "";
    public string FileName => System.IO.Path.GetFileName(Path);

    [ObservableProperty]
    public partial string Status { get; set; } = "Ready";

    [ObservableProperty]
    public partial double Progress { get; set; }

    /// <summary>Editions found in the source ISO's install.wim (empty while scanning / ESD media).</summary>
    public ObservableCollection<EditionItem> Editions { get; } = [];

    [ObservableProperty]
    public partial string EditionsHeader { get; set; } = "Editions";

    public bool HasMultipleEditions => Editions.Count > 1;

    public Visibility EditionsVisibility => HasMultipleEditions ? Visibility.Visible : Visibility.Collapsed;

    /// <summary>Fills the picker from a scan result and refreshes visibility bindings.</summary>
    internal void SetEditions(IEnumerable<(int Index, string Name)> images)
    {
        foreach (var (index, name) in images)
            Editions.Add(new EditionItem(index, name));
        OnPropertyChanged(nameof(HasMultipleEditions));
        OnPropertyChanged(nameof(EditionsVisibility));
    }

    /// <summary>Ring-buffered build log lines (raw tool output), newest at the end.</summary>
    public ObservableCollection<string> LogLines { get; } = [];

    internal void AppendLog(string line)
    {
        LogLines.Add(line);
        while (LogLines.Count > MaxLogLines)
            LogLines.RemoveAt(0);
    }

    internal const int MaxLogLines = 500;

    public IsoItem() { }
}

public partial class BuilderViewModel : ObservableObject
{
    private readonly InjectionPipeline _pipeline;
    private readonly Core.Wim.WimService _wimService;
    private readonly Core.Iso.IsoMountService _mountService;
    private readonly Services.EngineService _engine;
    private CancellationTokenSource? _cts;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasSelection))]
    [NotifyCanExecuteChangedFor(nameof(BuildCommand))]
    public partial IsoItem? SelectedIso { get; set; }

    [ObservableProperty]
    public partial bool IsBuilding { get; set; }

    /// <summary>Show the engine's own console window (debugging aid).</summary>
    [ObservableProperty]
    public partial bool ShowEngineConsole { get; set; } = true;

    partial void OnIsBuildingChanged(bool value) => NotifyBuildStates();

    public ObservableCollection<IsoItem> Isos { get; } = [];

    public bool HasSelection => SelectedIso is not null;

    public BuilderViewModel(InjectionPipeline pipeline, Core.Wim.WimService wimService, Core.Iso.IsoMountService mountService,
        Services.EngineService engine)
    {
        _pipeline = pipeline;
        _wimService = wimService;
        _mountService = mountService;
        _engine = engine;
    }

    /// <summary>Adds dropped/browsed ISOs to the sidebar (dedup by path), then scans editions.</summary>
    public void AddIso(string path)
    {
        if (!System.IO.Path.GetExtension(path).Equals(".iso", StringComparison.OrdinalIgnoreCase)) return;
        if (Isos.Any(i => i.Path.Equals(path, StringComparison.OrdinalIgnoreCase))) return;

        var item = new IsoItem { Path = path };
        Isos.Add(item);
        SelectedIso ??= item;

        _ = ScanEditionsAsync(item);
    }

    /// <summary>
    /// Background edition scan: mount the ISO, read install.wim's image table via wimlib
    /// (metadata only — fast), dismount. Never blocks intake; failures leave the picker hidden.
    /// </summary>
    private async Task ScanEditionsAsync(IsoItem item)
    {
        try
        {
            var drive = await Task.Run(() => _mountService.MountAsync(item.Path)).ConfigureAwait(false);
            try
            {
                // MountAsync returns a bare letter ("H:"); wimlib needs "H:\" to join sources\install.wim.
                var root = drive.EndsWith(':') ? $"{drive}\\" : drive;
                var images = await Task.Run(() => _wimService.ListImages(root)).ConfigureAwait(false);

                App.MainWindowEnqueue(() => item.SetEditions(images.Select(i => (i.Index, i.Name))));
            }
            finally
            {
                await Task.Run(() => _mountService.DismountAsync(item.Path)).ConfigureAwait(false);
            }
        }
        catch (Exception ex)
        {
            // ESD media or unreadable WIM: no picker, all-edition default applies at build time.
            App.Services.GetService<ILogger<BuilderViewModel>>()?.LogWarning(ex, "Edition scan failed for {Iso}", item.Path);
        }
    }

    [RelayCommand]
    private void PickIso()
    {
        // WinRT FileOpenPicker throws COMException in elevated processes; use Win32 dialog.
        var path = Services.Win32FilePicker.PickIso(App.MainWindowHandle);
        if (path is not null)
        {
            AddIso(path);
        }
    }

    [RelayCommand]
    private void RemoveIso(IsoItem? item)
    {
        if (item is null || IsBuilding) return;
        Isos.Remove(item);
        if (SelectedIso == item) SelectedIso = Isos.FirstOrDefault();
    }

    /// <summary>Output is always written next to the source as AkariOS.iso.</summary>
    public static string GetOutputPathFor(string sourceIso) =>
        System.IO.Path.Combine(System.IO.Path.GetDirectoryName(sourceIso) ?? "", "AkariOS.iso");

    private bool CanApply() => !IsBuilding && Services.EngineService.IsEnginePresent();

    /// <summary>
    /// "Apply now": runs the AkariOS playbook against THIS system via the bundled engine.
    /// One UAC prompt; console visibility follows ShowEngineConsole (debugging aid).
    /// </summary>
    [RelayCommand(CanExecute = nameof(CanApply))]
    private async Task ApplyNowAsync()
    {
        var item = SelectedIso ?? new IsoItem { Path = "(this system)" };
        IsBuilding = true;
        item.Status = "Preparing engine…";
        item.Progress = 0;
        _cts = new CancellationTokenSource();

        try
        {
            // TODO(Phase 2): real options from a FeaturePages UI. Until then, engine defaults.
            var options = new List<string>();

            var result = await _engine.RunPlaybookAsync(
                options,
                onProgress: (pct, status) => App.MainWindowEnqueue(() =>
                {
                    item.Progress = pct;
                    if (!string.IsNullOrEmpty(status)) item.Status = status;
                }),
                onLogLine: line => App.MainWindowEnqueue(() => item.AppendLog(line)),
                showConsole: ShowEngineConsole,
                ct: _cts.Token).ConfigureAwait(true);

            item.Status = result.Cancelled ? "Cancelled."
                : result.ExitCode == 0 ? "Done! Playbook applied to this system."
                : $"Failed (exit {result.ExitCode}) — check the log.";
            if (result.ExitCode != 0) item.Progress = 0;
        }
        catch (Exception ex)
        {
            item.Status = $"Failed: {ex.Message}";
        }
        finally
        {
            IsBuilding = false;
            _cts?.Dispose();
            _cts = null;
            NotifyBuildStates();
        }
    }

    private void NotifyBuildStates()
    {
        BuildCommand.NotifyCanExecuteChanged();
        CancelBuildCommand.NotifyCanExecuteChanged();
        ApplyNowCommand.NotifyCanExecuteChanged();
    }

    private bool CanCancel() => IsBuilding;

    [RelayCommand(CanExecute = nameof(CanCancel))]
    private void CancelBuild()
    {
        _cts?.Cancel();
    }

    private bool CanBuild() => SelectedIso is not null && !IsBuilding;

    [RelayCommand(CanExecute = nameof(CanBuild))]
    private async Task BuildAsync()
    {
        if (SelectedIso is null) return;
        var iso = SelectedIso;

        IsBuilding = true;
        iso.Status = "Starting…";
        iso.Progress = 0;
        _cts = new CancellationTokenSource();

        var progress = new Progress<ProgressReport>(report =>
        {
            App.MainWindowEnqueue(() =>
            {
                if (report.Percent.HasValue) iso.Progress = report.Percent.Value;
                iso.Status = report.Message;
            });
        });

        try
        {
            var options = new InjectionOptions
            {
                SourceIsoPath = iso.Path,
                PayloadFiles = AkariPipelineFactory.DefaultPayload.Where(File.Exists).ToList(),
                SelectedImageIndexes = iso.Editions.Where(e => e.IsSelected).Select(e => e.Index).ToList(),
            };
            if (options.PayloadFiles.Count == 0)
                throw new FileNotFoundException("WinSux.ps1 payload missing next to the app.");

            var result = await _pipeline.RunAsync(options, progress, _cts.Token, log: line =>
                App.MainWindowEnqueue(() => iso.AppendLog(line)));
            iso.Status = result.Success
                ? "Done! AkariOS.iso created next to your source ISO."
                : $"Failed: {result.ErrorMessage}";
            if (!result.Success) iso.Progress = 0;
        }
        catch (Exception ex)
        {
            iso.Status = $"Failed: {ex.Message}";
        }
        finally
        {
            IsBuilding = false;
            _cts?.Dispose();
            _cts = null;
        }
    }
}
