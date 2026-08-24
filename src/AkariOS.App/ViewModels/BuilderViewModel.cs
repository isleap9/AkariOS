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
    private async Task PickIsoAsync()
    {
        var picker = new Windows.Storage.Pickers.FileOpenPicker();
        WinRT.Interop.InitializeWithWindow.Initialize(picker, App.MainWindowHandle);
        picker.FileTypeFilter.Add(".iso");
        foreach (var file in await picker.PickMultipleFilesAsync())
            AddIso(file.Path);
    }

    [RelayCommand]
    private void RemoveIso(IsoItem? item)
    {
        if (item is null || IsBuilding) return;
        Isos.Remove(item);
        if (SelectedIso == item) SelectedIso = Isos.FirstOrDefault();
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

            var result = await _pipeline.RunAsync(options, progress, _cts.Token);
            iso.Status = result.Success
                ? $"Done → {System.IO.Path.GetFileName(result.OutputIsoPath)}"
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
