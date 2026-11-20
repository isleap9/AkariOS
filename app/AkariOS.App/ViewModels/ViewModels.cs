using AkariOS.App.Shell;
using AkariOS.Core;
using AkariOS.Framework.Navigation;
using AkariOS.Framework.Services;
using AkariOS.Framework.ViewModels;
using CommunityToolkit.Mvvm.Input;

namespace AkariOS.App.ViewModels;

/// <summary>A page the WinUI 3 app doesn't have yet.</summary>
public sealed record Placeholder(string Title, string? Batch);

public sealed partial class PlaceholderViewModel : ViewModelBase, INavigationAware
{
    private string _text = "";

    public string Text
    {
        get => _text;
        private set => SetProperty(ref _text, value);
    }

    public void OnNavigatedTo(object? parameter)
    {
        if (parameter is not Placeholder p) return;
        Title = p.Title;
        Text = p.Batch is null
            ? "This page isn't in the native app yet."
            : $"This page comes to the native app with batch {p.Batch} of the WinUI 3 plan. The PowerShell app has it today.";
    }

    public void OnNavigatedFrom() { }
}
