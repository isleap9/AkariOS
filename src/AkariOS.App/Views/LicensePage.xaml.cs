using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Views;

public sealed partial class LicensePage : WizardStepPage
{
    public LicensePage() => InitializeComponent();

    public override WizardStepKind Kind => WizardStepKind.License;

    public bool Accepted => AcceptCheck.IsChecked == true;

    private void OnAcceptChanged(object sender, RoutedEventArgs e) =>
        WizardState.LicenseAccepted = Accepted;
}
