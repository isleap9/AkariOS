using System.Runtime.InteropServices;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using AkariOS.App.ViewModels;
using Windows.System;

namespace AkariOS.App.Views;

/// <summary>
/// Setup wizard shell: left step tracker + per-step content + Back/Next/Cancel footer.
/// Step contents are built in code for now (fast to iterate); XAML-ifying per-step
/// templates can come later once the flow is settled.
/// </summary>
public sealed partial class WizardPage : Page
{
    public WizardViewModel Vm { get; } = new();

    public WizardPage()
    {
        InitializeComponent();
        StepContent.Content = BuildLicenseContent();
        RefreshButtons();
    }

    // ----- step content builders (Slice 1: only License is real) -----

    private UIElement BuildLicenseContent()
    {
        var accept = new CheckBox { Content = "I have read and accept the license agreement" };
        return new StackPanel
        {
            Spacing = 14,
            Children =
            {
                new TextBlock { Text = "AkariOS", Style = (Style)Application.Current.Resources["TitleTextBlockStyle"] },
                new TextBlock
                {
                    Text = "Review the terms before applying the playbook",
                    Opacity = 0.75,
                },
                new InfoBar
                {
                    IsOpen = true,
                    Severity = InfoBarSeverity.Warning,
                    Title = "This will modify your system",
                    Message = "The playbook removes services, apps and system components. Use it only on a machine you are willing to reconfigure.",
                    IsClosable = false,
                },
                accept,
            },
        };
    }

    // ----- navigation -----

    private void OnNext(object sender, RoutedEventArgs e)
    {
        if (Vm.CurrentIndex == WizardViewModel.LicenseIndex)
        {
            // License checkbox gate lives here until Slice 2 moves checks into the VM.
            if (FindLicenseCheckBox() is not { IsChecked: true })
                return;
            Vm.LicenseAccepted = true;
        }

        if (Vm.TryNext())
        {
            StepContent.Content = BuildPlaceholderForStep(Vm.CurrentIndex);
            RefreshButtons();
        }
    }

    private void OnBack(object sender, RoutedEventArgs e)
    {
        Vm.Back();
        StepContent.Content = BuildPlaceholderForStep(Vm.CurrentIndex);
        RefreshButtons();
    }

    private void OnCancel(object sender, RoutedEventArgs e)
    {
        // TODO(Phase 2): confirm if engine is running; then close or return to home page.
        App.MainWindow?.Close();
    }

    private void OnDiscordClick(object sender, RoutedEventArgs e) =>
        _ = Launcher.LaunchUriAsync(new Uri("https://discord.gg/UjjmYM6ytj"));

    private void RefreshButtons()
    {
        BackButton.IsEnabled = !Vm.IsFirst;
        NextButton.IsEnabled = !Vm.IsLast;
        NextButton.Content = Vm.IsLast ? "Finish" : "Next";
        CancelButton.IsEnabled = true;
    }

    private CheckBox? FindLicenseCheckBox() =>
        (StepContent.Content as StackPanel)?.Children.OfType<CheckBox>().FirstOrDefault();

    private static UIElement BuildPlaceholderForStep(int index) => index switch
    {
        1 => Placeholder("System Check", "Hardware summary and requirement verification land in Slice 2."),
        2 => Placeholder("Configuration", "Playbook feature options land in Slice 3."),
        3 => Placeholder("Optimization", "Engine run with progress lands in Slice 4."),
        4 => Placeholder("Finished", "Completion summary lands in Slice 4."),
        _ => Placeholder("AkariOS", ""),
    };

    private static UIElement Placeholder(string title, string subtitle) =>
        new StackPanel
        {
            Spacing = 10,
            Children =
            {
                new TextBlock { Text = title, Style = (Style)Application.Current.Resources["TitleTextBlockStyle"] },
                new TextBlock { Text = subtitle, Opacity = 0.7, TextWrapping = TextWrapping.Wrap },
            },
        };
}
