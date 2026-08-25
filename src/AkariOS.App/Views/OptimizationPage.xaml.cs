using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.Extensions.DependencyInjection;
using AkariOS.App.Services;

namespace AkariOS.App.Views;

public sealed partial class OptimizationPage : WizardStepPage
{
    private readonly Services.EngineService _engine;

    public OptimizationPage()
    {
        InitializeComponent();
        // Resolved from the app's DI container (page is created by the navigation service).
        _engine = App.Services.GetRequiredService<Services.EngineService>();
    }

    public override WizardStepKind Kind => WizardStepKind.Optimization;

    public bool RunCompleted { get; private set; }

    private async void OnStartClick(object sender, RoutedEventArgs e)
    {
        IdlePanel.Visibility = Visibility.Collapsed;
        RunningPanel.Visibility = Visibility.Visible;
        DoneBar.IsOpen = false;
        RunCompleted = false;

        // Options come from the Configuration page's manifest selections.
        var options = WizardState.SelectedOptions.Count > 0
            ? WizardState.SelectedOptions.ToList()
            : LoadOptionsFromManifest();

        var log = new System.Collections.ObjectModel.ObservableCollection<string>();
        LogList.ItemsSource = log;

        try
        {
            var result = await _engine.RunPlaybookAsync(
                options,
                onProgress: (pct, status) => App.MainWindowEnqueue(() =>
                {
                    Progress.Value = pct;
                    PercentText.Text = $"{pct}%";
                    if (!string.IsNullOrEmpty(status)) CurrentTask.Text = status;
                }),
                onLogLine: line => App.MainWindowEnqueue(() =>
                {
                    log.Add(line);
                    while (log.Count > 500) log.RemoveAt(0);
                }),
                showConsole: ShowConsoleCheck.IsChecked == true,
                ct: CancellationToken.None).ConfigureAwait(true);

            RunCompleted = result.ExitCode == 0 && !result.Cancelled;
            DoneBar.Severity = RunCompleted ? InfoBarSeverity.Success : InfoBarSeverity.Error;
            DoneBar.Title = RunCompleted ? "Playbook applied" : $"Engine exited with code {result.ExitCode}";
            DoneBar.Message = RunCompleted
                ? "Continue to the Finished step."
                : "Check the engine output above.";
            DoneBar.IsOpen = true;
        }
        catch (Exception ex)
        {
            RunCompleted = false;
            DoneBar.Severity = InfoBarSeverity.Error;
            DoneBar.Title = "Failed to run the engine";
            DoneBar.Message = ex.Message;
            DoneBar.IsOpen = true;
        }
    }

    private List<string> LoadOptionsFromManifest()
    {
        try
        {
            var dir = Services.EngineService.PlaybookWorkDir;
            if (!Directory.Exists(Path.Combine(dir, "playbook.conf")))
                Services.EngineService.EnsurePlaybookExtracted();
            return PlaybookManifest.Parse(dir).SelectedOptions.ToList();
        }
        catch
        {
            return [];
        }
    }
}
