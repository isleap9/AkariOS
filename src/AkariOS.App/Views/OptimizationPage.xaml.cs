using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Views;

public sealed partial class OptimizationPage : WizardStepPage
{
    public OptimizationPage() => InitializeComponent();

    public override WizardStepKind Kind => WizardStepKind.Optimization;
}
