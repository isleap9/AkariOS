using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using AkariOS.App.ViewModels;

namespace AkariOS.App.Views;

public sealed partial class BuilderPage : Page
{
    public BuilderViewModel ViewModel { get; }

    public BuilderPage(BuilderViewModel viewModel)
    {
        ViewModel = viewModel;
        InitializeComponent();
        ViewModel.PropertyChanged += (_, e) =>
        {
            if (e.PropertyName is nameof(ViewModel.LogLines))
            {
                LogBorder.Visibility = ViewModel.LogLines.Count > 0 ? Visibility.Visible : Visibility.Collapsed;
            }
            else if (e.PropertyName is nameof(ViewModel.SourceIsoPath) && ViewModel.SourceIsoPath is { } iso)
            {
                DropZoneText.Text = iso; // show the chosen file in the drop zone
            }
            else if (e.PropertyName is nameof(ViewModel.IsBuilding))
            {
                BuildButton.IsEnabled = !ViewModel.IsBuilding && ViewModel.SourceIsoPath is not null;
            }
        };
    }

    private void OnDragOver(object sender, DragEventArgs e)
    {
        e.AcceptedOperation = Windows.ApplicationModel.DataTransfer.DataPackageOperation.Copy;
        DropZone.Opacity = 0.8;
    }

    private void OnDragLeave(object sender, DragEventArgs e) => DropZone.Opacity = 1;

    private async void OnDrop(object sender, DragEventArgs e)
    {
        DropZone.Opacity = 1;
        var deferral = e.GetDeferral();
        try
        {
            if (e.DataView.Contains(Windows.ApplicationModel.DataTransfer.StandardDataFormats.StorageItems))
            {
                var items = await e.DataView.GetStorageItemsAsync();
                var file = items.FirstOrDefault(i => i.Path.EndsWith(".iso", StringComparison.OrdinalIgnoreCase));
                if (file is not null)
                {
                    ViewModel.DropIsoCommand.Execute(file.Path);
                    return;
                }
            }
        }
        finally
        {
            deferral.Complete();
        }
    }
}
