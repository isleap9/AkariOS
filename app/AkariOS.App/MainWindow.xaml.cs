using System.Windows;

namespace AkariOS.App;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        VersionText.Text = $"AkariOS {Core.AkariInfo.Version}";
    }
}
