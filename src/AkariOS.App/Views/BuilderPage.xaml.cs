using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Input;
using AkariOS.App.ViewModels;

namespace AkariOS.App.Views;

public sealed partial class BuilderPage : Page
{
    public BuilderViewModel ViewModel { get; }

    public BuilderPage(BuilderViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
    }

    private void OnDragOver(object sender, DragEventArgs e)
    {
        e.AcceptedOperation = Windows.ApplicationModel.DataTransfer.DataPackageOperation.Copy;
        DropHint.Opacity = 0.9;
    }

    private void OnDragLeave(object sender, DragEventArgs e) => DropHint.Opacity = 0;

    private async void OnDrop(object sender, DragEventArgs e)
    {
        DropHint.Opacity = 0;
        var deferral = e.GetDeferral();
        try
        {
            if (!e.DataView.Contains(Windows.ApplicationModel.DataTransfer.StandardDataFormats.StorageItems))
                return;

            var items = await e.DataView.GetStorageItemsAsync();
            foreach (var item in items.Where(i => i.Path.EndsWith(".iso", StringComparison.OrdinalIgnoreCase)))
                ViewModel.AddIso(item.Path);
        }
        finally
        {
            deferral.Complete();
        }
    }

    private void OnItemRightTapped(object sender, RightTappedRoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: string path })
        {
            var item = ViewModel.Isos.FirstOrDefault(i => i.Path == path);
            if (item is not null && !ViewModel.IsBuilding)
                ViewModel.RemoveIsoCommand.Execute(item);
        }
    }
}
