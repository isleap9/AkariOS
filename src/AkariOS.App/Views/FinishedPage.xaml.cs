using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Views;

public sealed partial class FinishedPage : WizardStepPage
{
    public FinishedPage() => InitializeComponent();

    public override WizardStepKind Kind => WizardStepKind.Finished;
}
