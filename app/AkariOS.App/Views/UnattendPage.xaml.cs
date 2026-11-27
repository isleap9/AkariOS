using AkariOS.App.ViewModels;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Views;

/// <summary>Install USB, from <see cref="UnattendViewModel"/>; his sections through <see cref="UnattendFormView"/>.</summary>
public sealed partial class UnattendPage : Page
{
    private readonly UnattendFormView _form = new();

    public UnattendViewModel ViewModel { get; }

    public UnattendPage(UnattendViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
        PageLayout.Fit(Scroller, Column);
        DataContext = viewModel;
        // the form starts before its controls are made, so they show its values
        ViewModel.Shown();
        _form.AddSections(Sections, ViewModel.Sections);
        Unloaded += (_, _) => _form.Detach();
        SizeChanged += (_, e) => Layout(e.NewSize.Width);
    }

    // narrow: the drive bar's buttons under the drive
    private void Layout(double width)
    {
        var narrow = width < 700;
        Grid.SetColumn(DriveButtons, narrow ? 1 : 2);
        Grid.SetRow(DriveButtons, narrow ? 1 : 0);
    }
}
