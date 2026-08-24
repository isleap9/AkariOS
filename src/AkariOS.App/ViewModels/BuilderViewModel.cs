using System.Collections.ObjectModel;
using AkariOS.Core;
using AkariOS.Core.Pipeline;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AkariOS.App.ViewModels;

/// <summary>An ISO added to the sidebar via drag-drop or browse.</summary>
public partial class IsoItem : ObservableObject
{
    public string Path { get; init; } = "";
    public string FileName => System.IO.Path.GetFileName(Path);

    [ObservableProperty]
    public partial string Status { get; set; } = "Ready";

    [ObservableProperty]
    public partial double Progress { get; set; }

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
    private CancellationTokenSource? _cts;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(HasSelection))]
    [NotifyCanExecuteChangedFor(nameof(BuildCommand))]
    public partial IsoItem? SelectedIso { get; set; }

    [ObservableProperty]
    public partial bool IsBuilding { get; set; }

    partial void OnIsBuildingChanged(bool value) => NotifyBuildStates();

    public ObservableCollection<IsoItem> Isos { get; } = [];

    public bool HasSelection => SelectedIso is not null;

    public BuilderViewModel(InjectionPipeline pipeline)
    {
        _pipeline = pipeline;
    }

    /// <summary>Adds dropped/browsed ISOs to the sidebar (dedup by path).</summary>
    public void AddIso(string path)
    {
        if (!System.IO.Path.GetExtension(path).Equals(".iso", StringComparison.OrdinalIgnoreCase)) return;
        if (Isos.Any(i => i.Path.Equals(path, StringComparison.OrdinalIgnoreCase))) return;

        var item = new IsoItem { Path = path };
        Isos.Add(item);
        SelectedIso ??= item;
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

    private void NotifyBuildStates()
    {
        BuildCommand.NotifyCanExecuteChanged();
        CancelBuildCommand.NotifyCanExecuteChanged();
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
