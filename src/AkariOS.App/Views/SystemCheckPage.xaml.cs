using Microsoft.Extensions.DependencyInjection;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using AkariOS.App.Services;

namespace AkariOS.App.Views;

public sealed partial class SystemCheckPage : WizardStepPage
{
    public SystemCheckPage()
    {
        InitializeComponent();
        Loaded += (_, _) => RunChecks();
    }

    public override WizardStepKind Kind => WizardStepKind.SystemCheck;

    private void RunChecks()
    {
        FillSpecs();
        EvaluateRequirements();
    }

    private unsafe void FillSpecs()
    {
        try
        {
            var arch = Environment.Is64BitOperatingSystem ? "x64" : "x86";
            var cores = Environment.ProcessorCount;
            var build = Environment.OSVersion.Version.Build;
            var mem = GetRamGb();
            SpecText.Text = $"CPU cores: {cores}\nRAM: {mem:N1} GB\nOS build: {build} ({arch})";
        }
        catch (Exception ex)
        {
            SpecText.Text = $"Could not read system info: {ex.Message}";
        }
    }

    private static string GetRamGb()
    {
        try
        {
            var status = GlobalMemoryStatusEx();
            return (status.ullTotalPhys / (1024d * 1024 * 1024)).ToString("N1");
        }
        catch { return "?"; }
    }

    // ----- requirement cards -----

    private void EvaluateRequirements()
    {
        var requirements = LoadDeclaredRequirements();

        // Re-run on every visit so toggles made since last time are picked up.
        RequirementsList.Children.Clear();
        AllGoodBar.IsOpen = false;

        var service = App.Services.GetRequiredService<Services.RequirementsService>();
        var results = service.Evaluate(requirements);

        foreach (var check in results.Where(r => !r.IsMet))
            RequirementsList.Children.Add(BuildRequirementCard(check));

        if (results.Count > 0 && results.All(r => r.IsMet))
        {
            AllGoodBar.IsOpen = true;
            WizardFlow.RequirementsMet = true;
        }
        else
        {
            WizardFlow.RequirementsMet = false;
        }
        WizardFlow.NotifyStateChanged();
    }

    /// <summary>Requirements declared in playbook.conf, or sensible defaults if unreadable.</summary>
    private List<string> LoadDeclaredRequirements()
    {
        try
        {
            var dir = Services.EngineService.PlaybookWorkDir;
            if (!File.Exists(Path.Combine(dir, "playbook.conf")))
                Services.EngineService.EnsurePlaybookExtracted();
            return PlaybookManifest.Parse(dir).Requirements.ToList();
        }
        catch
        {
            return ["Internet", "NoAntivirus", "PluggedIn", "DefenderToggled", "UCPDDisabled"];
        }
    }

    private Border BuildRequirementCard(RequirementCheck check)
    {
        var card = new Border
        {
            Background = (Brush)Application.Current.Resources["CardBackgroundFillColorDefaultBrush"],
            BorderBrush = (Brush)Application.Current.Resources["CardStrokeColorDefaultBrush"],
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(8),
            Padding = new Thickness(16),
        };

        var grid = new Grid { ColumnSpacing = 12 };
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        grid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var text = new StackPanel { Spacing = 2 };
        text.Children.Add(new TextBlock
        {
            Text = check.Title,
            Style = (Style)Application.Current.Resources["BodyStrongTextBlockStyle"],
        });
        text.Children.Add(new TextBlock
        {
            Text = check.Details ?? check.Description,
            Opacity = 0.75,
            FontSize = 13,
            TextWrapping = TextWrapping.Wrap,
        });
        grid.Children.Add(text);

        if (!check.IsMet && check.CanAutoFix)
        {
            var btn = new Button { Content = "Disable" };
            btn.Click += async (_, _) =>
            {
                btn.IsEnabled = false;
                var ok = RequirementsService.TryAutoFix(check.Id);
                if (ok)
                {
                    // Give the action a beat to take effect, then re-verify everything.
                    await Task.Delay(2500);
                    EvaluateRequirements();
                }
                else
                {
                    btn.IsEnabled = true;
                }
            };
            grid.Children.Add(btn);
            Grid.SetColumn(btn, 1);
        }

        card.Child = grid;
        return card;
    }

    // ----- native memory query -----

    [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
    private struct MEMORYSTATUSEX
    {
        public uint dwLength;
        public uint dwMemoryLoad;
        public ulong ullTotalPhys;
        public ulong ullAvailPhys;
        public ulong ullTotalPageFile;
        public ulong ullAvailPageFile;
        public ulong ullTotalVirtual;
        public ulong ullAvailVirtual;
        public ulong ullAvailExtendedVirtual;
    }

    [System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GlobalMemoryStatusEx(ref MEMORYSTATUSEX lpBuffer);

    private static MEMORYSTATUSEX GlobalMemoryStatusEx()
    {
        var s = new MEMORYSTATUSEX { dwLength = (uint)System.Runtime.InteropServices.Marshal.SizeOf<MEMORYSTATUSEX>() };
        if (!GlobalMemoryStatusEx(ref s)) throw new System.ComponentModel.Win32Exception();
        return s;
    }
}
