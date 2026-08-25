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
            {
                // Extract on demand so Configuration works even if the user never hit Apply.
                _ = Services.EngineService.EnsurePlaybookExtracted();
            }

            Manifest = PlaybookManifest.Parse(dir);
            Subtitle.Text = $"{Manifest.Title} v{Manifest.Version} — customize how the playbook will be applied.";
            BuildCards();
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
        }
    }

    private void BuildCards()
    {
        foreach (var page in Manifest!.FeaturePages)
        {
            var card = new Border
            {
                Background = (Brush)Application.Current.Resources["CardBackgroundFillColorDefaultBrush"],
                BorderBrush = (Brush)Application.Current.Resources["CardStrokeColorDefaultBrush"],
                BorderThickness = new Thickness(1),
                CornerRadius = new CornerRadius(8),
                Padding = new Thickness(16),
            };

            var stack = new StackPanel { Spacing = 10 };
            stack.Children.Add(new TextBlock
            {
                Text = page.Description,
                Style = (Style)Application.Current.Resources["BodyStrongTextBlockStyle"],
            });

            foreach (var option in page.Options)
            {
                var cb = new CheckBox
                {
                    Content = option.Text,
                    IsChecked = option.IsSelected,
                    MinWidth = 0,
                };
                cb.Checked += (_, _) => option.IsSelected = true;
                cb.Unchecked += (_, _) => option.IsSelected = false;
                stack.Children.Add(cb);
            }

            card.Child = stack;
            Root.Children.Add(card);
        }
    }
}
