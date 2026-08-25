using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using AkariOS.App.Services;

namespace AkariOS.App.Views;

public sealed partial class ConfigurationPage : WizardStepPage
{
    public ConfigurationPage()
    {
        InitializeComponent();
        Loaded += (_, _) => { if (Manifest is null) LoadPlaybook(); };
    }

    public override WizardStepKind Kind => WizardStepKind.Configuration;

    /// <summary>Manifest loaded by this page (non-null once Loaded ran successfully).</summary>
    public PlaybookManifest? Manifest { get; private set; }

    private void LoadPlaybook()
    {
        var dir = Services.EngineService.PlaybookWorkDir;
        try
        {
            if (!File.Exists(Path.Combine(dir, "playbook.conf")))
                Services.EngineService.EnsurePlaybookExtracted();

            Manifest = PlaybookManifest.Parse(dir);
            Subtitle.Text = $"{Manifest.Title} v{Manifest.Version} — customize how the playbook will be applied.";
        }
        catch (Exception ex)
        {
            Root.Children.Add(new InfoBar
            {
                IsOpen = true,
                Severity = InfoBarSeverity.Error,
                Title = "Could not load the playbook",
                Message = ex.Message,
                IsClosable = false,
            });
            SelectOptionsButton.IsEnabled = false;
        }
    }

    /// <summary>Opens the feature pages as sequential ContentDialogs (Nexus-style flow).</summary>
    private async void OnSelectOptionsClick(object sender, RoutedEventArgs e)
    {
        if (Manifest is null) return;

        var pages = Manifest.FeaturePages.ToList();
        for (var i = 0; i < pages.Count; i++)
        {
            var page = pages[i];
            var dialog = BuildPageDialog(page, i + 1, pages.Count);
            dialog.XamlRoot = Root.XamlRoot;
            await dialog.ShowAsync();
        }

        UpdateSummary();
        WizardFlow.NotifyStateChanged(); // re-evaluate the shell's Next button
    }

    private ContentDialog BuildPageDialog(PlaybookFeaturePage page, int index, int total)
    {
        var stack = new StackPanel { Spacing = 10, MinWidth = 380 };

        foreach (var option in page.Options)
        {
            var cb = new CheckBox { Content = option.Text, IsChecked = option.IsSelected };
            cb.Checked += (_, _) => option.IsSelected = true;
            cb.Unchecked += (_, _) => option.IsSelected = false;
            stack.Children.Add(cb);
        }

        var dialog = new ContentDialog
        {
            Title = $"{page.Description}   ({index}/{total})",
            Content = new ScrollViewer { MaxHeight = 400, Content = stack },
            PrimaryButtonText = index == total ? "Done" : "Next",
            CloseButtonText = "Cancel",
            DefaultButton = ContentDialogButton.Primary,
        };
        return dialog;
    }

    private void UpdateSummary()
    {
        var selected = Manifest!.FeaturePages.SelectMany(p => p.Options).Where(o => o.IsSelected).ToList();

        NotConfiguredBar.IsOpen = selected.Count == 0;
        NotConfiguredBar.Message = "You must configure the playbook options before proceeding.";

        SelectionsSummary.Text = selected.Count == 0
            ? ""
            : $"Selected: {string.Join(", ", selected.Select(o => o.Text))}";
        SelectionsSummary.Visibility = selected.Count > 0 ? Visibility.Visible : Visibility.Collapsed;

        // Expose to the shell (MainWindow reads this when leaving Configuration).
        SelectedOptionsList.Clear();
        SelectedOptionsList.AddRange(selected.Select(o => o.Name));
        ConfiguredAtLeastOnce = true;
    }

    /// <summary>Option names captured from the last completed pass (read by MainWindow).</summary>
    public static readonly List<string> SelectedOptionsList = [];
    public static bool ConfiguredAtLeastOnce { get; private set; }
}
