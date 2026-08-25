using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Views;

public sealed partial class ConfigurationPage : WizardStepPage
{
    public ConfigurationPage() => InitializeComponent();

    public override WizardStepKind Kind => WizardStepKind.Configuration;
}
