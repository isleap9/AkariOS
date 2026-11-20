using AkariOS.App.ViewModels;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Views;

/// <summary>Downloads, from <see cref="DownloadsViewModel"/>; the view fills the categories' SelectorBar.</summary>
public sealed partial class DownloadsPage : Page
{
    public DownloadsViewModel ViewModel { get; }

    public DownloadsPage(DownloadsViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
        PageLayout.Fit(Scroller, Column);
        DataContext = viewModel;
        foreach (var c in viewModel.Categories)
        {
            var item = new SelectorBarItem { Text = c, Tag = c };
            Categories.Items.Add(item);
            if (c == viewModel.Category) Categories.SelectedItem = item;
        }
        Loaded += (_, _) => ViewModel.Open();
    }

    private void OnCategory(SelectorBar sender, SelectorBarSelectionChangedEventArgs args)
    {
        if (sender.SelectedItem?.Tag is string c) ViewModel.Category = c;
    }
}
