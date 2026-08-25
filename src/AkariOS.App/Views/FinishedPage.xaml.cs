using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Views;

public sealed partial class FinishedPage : WizardStepPage
{
    public FinishedPage() => InitializeComponent();

    public override WizardStepKind Kind => WizardStepKind.Finished;

    private void OnRestartClick(object sender, RoutedEventArgs e)
    {
        // Full shutdown-restart so RunOnce/first-logon tasks re-arm cleanly.
        var psi = new System.Diagnostics.ProcessStartInfo
        {
            FileName = "shutdown",
            Arguments = "/r /t 5 /c \"AkariOS\" /d p:4:1",
            UseShellExecute = true,
            CreateNoWindow = true,
        };
        System.Diagnostics.Process.Start(psi);
    }
}
