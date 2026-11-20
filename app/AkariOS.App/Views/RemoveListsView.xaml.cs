using System.ComponentModel;
using AkariOS.App.ViewModels;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Views;

/// <summary>The Remove lists of an <see cref="AppsStepViewModel"/> (Guided's Apps step, the Remove apps page). Glue only:
/// each control hands its use to the view model and shows what it says.</summary>
public sealed partial class RemoveListsView : UserControl
{
    public static readonly DependencyProperty AppsProperty =
        DependencyProperty.Register(nameof(Apps), typeof(AppsStepViewModel), typeof(RemoveListsView), new PropertyMetadata(null, (d, e) => ((RemoveListsView)d).Attach(e.OldValue as AppsStepViewModel)));

    private bool _filling;

    public RemoveListsView()
    {
        InitializeComponent();
        foreach (var name in AppsStepViewModel.RemoveLists) Lists.Items.Add(new SelectorBarItem { Text = name, Tag = name });
    }

    public AppsStepViewModel? Apps
    {
        get => (AppsStepViewModel?)GetValue(AppsProperty);
        set => SetValue(AppsProperty, value);
    }

    private void Attach(AppsStepViewModel? old)
    {
        if (old is not null) old.PropertyChanged -= OnChanged;
        if (Apps is not null) Apps.PropertyChanged += OnChanged;
        Show();
    }

    private void OnChanged(object? sender, PropertyChangedEventArgs e) => Show();

    private void Show()
    {
        if (Apps is not { } a) return;
        _filling = true;
        Lists.SelectedItem = Lists.Items.FirstOrDefault(i => (string)i.Tag == a.RemoveList);
        _filling = false;
        Only.IsChecked = a.OnlyInstalled;
        Reading.IsActive = a.IsReading;
        Reading.Visibility = a.IsReading ? Visibility.Visible : Visibility.Collapsed;
        Table.Content = a.CurrentRemove;
    }

    private void OnList(SelectorBar sender, SelectorBarSelectionChangedEventArgs args)
    {
        if (!_filling && Apps is { } a && sender.SelectedItem?.Tag is string name) a.RemoveList = name;
    }

    private void OnRecommended(object sender, RoutedEventArgs e) => Apps?.SelectRecommendedCommand.Execute(null);
    private void OnAkariOS(object sender, RoutedEventArgs e) => Apps?.SelectAkariOSCommand.Execute(null);
    private void OnClear(object sender, RoutedEventArgs e) => Apps?.ClearRemovalsCommand.Execute(null);

    private void OnOnly(object sender, RoutedEventArgs e)
    {
        if (Apps is { } a) a.OnlyInstalled = Only.IsChecked == true;
    }
}
