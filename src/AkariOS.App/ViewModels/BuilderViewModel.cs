using System.Collections.ObjectModel;
using System.Diagnostics;
using AkariOS.Core;
using AkariOS.Core.Pipeline;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace AkariOS.App.ViewModels;

public partial class BuilderViewModel : ObservableObject
{
    private readonly InjectionPipeline _pipeline;
    private CancellationTokenSource? _cts;

    [ObservableProperty]
    [NotifyCanExecuteChangedFor(nameof(BuildCommand))]
    private string? _sourceIsoPath;

    [ObservableProperty]
    private bool _isBuilding;

    [ObservableProperty]
    private string _statusText = "";

    [ObservableProperty]
    private double _progressPercent;

    public ObservableCollection<string> LogLines { get; } = [];

    public BuilderViewModel(InjectionPipeline pipeline)
    {
        _pipeline = pipeline;
    }

    [RelayCommand]
    private async Task PickIsoAsync()
    {
        var picker = new Windows.Storage.Pickers.FileOpenPicker();
        WinRT.Interop.InitializeWithWindow.Initialize(picker, App.MainWindowHandle);
        picker.FileTypeFilter.Add(".iso");
        var file = await picker.PickSingleFileAsync();
        if (file is not null)
        {
            SourceIsoPath = file.Path;
            StatusText = "";
        }
    }

    /// <summary>Called by the drop zone when the user drops one or more files; takes the first .iso.</summary>
    [RelayCommand]
    private void DropIso(string path)
    {
        if (IsBuilding) return;
        if (Path.GetExtension(path).Equals(".iso", StringComparison.OrdinalIgnoreCase))
        {
            SourceIsoPath = path;
            StatusText = "";
        }
    }

    private bool CanBuild() => SourceIsoPath is not null && !IsBuilding;

    [RelayCommand(CanExecute = nameof(CanBuild))]
    private async Task BuildAsync()
    {
        if (SourceIsoPath is null) return;

        IsBuilding = true;
        ProgressPercent = 0;
        LogLines.Clear();
        StatusText = "";

        _cts = new CancellationTokenSource();
        var progress = new Progress<ProgressReport>(report =>
        {
            App.MainWindowEnqueue(() =>
            {
                LogLines.Add($"[{report.Stage}] {report.Message}");
                if (report.Percent.HasValue) ProgressPercent = report.Percent.Value;
                StatusText = report.Message;
            });
        });

        try
        {
            var options = new InjectionOptions
            {
                SourceIsoPath = SourceIsoPath,
                PayloadFiles = AkariPipelineFactory.DefaultPayload.Where(File.Exists).ToList(),
            };
            if (options.PayloadFiles.Count == 0)
                throw new FileNotFoundException("WinSux.ps1 payload missing next to the app.");

            var result = await _pipeline.RunAsync(options, progress, _cts.Token);
            StatusText = result.Success
                ? $"Done! Created {result.OutputIsoPath}"
                : $"Build failed: {result.ErrorMessage}";
        }
        catch (Exception ex)
        {
            StatusText = $"Build failed: {ex.Message}";
        }
        finally
        {
            IsBuilding = false;
            _cts?.Dispose();
            _cts = null;
        }
    }

    [RelayCommand]
    private void OpenOutputFolder()
    {
        if (SourceIsoPath is not null)
        {
            var output = Path.Combine(
                Path.GetDirectoryName(SourceIsoPath)!,
                Path.GetFileNameWithoutExtension(SourceIsoPath) + "_AkariOS.iso");
            if (Path.GetDirectoryName(output) is { } dir && Directory.Exists(dir))
                Process.Start(new ProcessStartInfo("explorer.exe", $"\"{dir}\""));
        }
    }
}
