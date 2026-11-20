using AkariOS.Framework.Services;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Shell;

/// <summary>A dialog message's paragraphs and its "- " lines (a list of consequences).</summary>
public sealed record DialogBlock(bool Item, string Text);

/// <summary>Dialog.ps1's pure parts.</summary>
public static class DialogText
{
    /// <summary>Get-AkariDialogBlocks: "- " or "• " lines are list items, other non-empty lines paragraphs.</summary>
    public static IReadOnlyList<DialogBlock> Blocks(string message)
    {
        var blocks = new List<DialogBlock>();
        foreach (var raw in message.Replace("\r", "", StringComparison.Ordinal).Split('\n'))
        {
            var line = raw.Trim();
            if (line.Length > 1 && (line[0] == '-' || line[0] == '•') && char.IsWhiteSpace(line[1])) blocks.Add(new(true, line[2..].Trim()));
            else if (line.Length > 0) blocks.Add(new(false, line));
        }
        return blocks;
    }
}

/// <summary>
/// Akari's dialogs (Dialog.ps1 on WinUI's ContentDialog): the main action first and accent (Enter), the cancel one
/// last (Esc), "- " lines shown as a list under their paragraph. One at a time (the framework's DialogService queues
/// them). Registered over the framework's own <see cref="DialogService"/>.
/// </summary>
public sealed class AkariDialogs(Func<XamlRoot?> root) : IDialogService
{
    private readonly DialogService _inner = new(root);

    /// <summary>WinUI 3's own ContentDialog look (without it a dialog made in code gets the bare template).</summary>
    public static void Style(ContentDialog d)
    {
        if (Application.Current?.Resources.TryGetValue("DefaultContentDialogStyle", out var s) == true && s is Style style) d.Style = style;
    }

    public static UIElement Content(string message)
    {
        var panel = new StackPanel { Spacing = 8, MaxWidth = 440 };
        foreach (var b in DialogText.Blocks(message))
        {
            if (!b.Item)
            {
                panel.Children.Add(new TextBlock { Text = b.Text, TextWrapping = TextWrapping.Wrap, IsTextSelectionEnabled = true });
                continue;
            }
            var row = new Grid { Margin = new Thickness(4, -2, 0, 0), ColumnSpacing = 8 };
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
            row.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
            row.Children.Add(new TextBlock { Text = "•" });
            var text = new TextBlock { Text = b.Text, TextWrapping = TextWrapping.Wrap };
            Grid.SetColumn(text, 1);
            row.Children.Add(text);
            panel.Children.Add(row);
        }
        return panel;
    }

    public Task<ContentDialogResult> ShowAsync(string title, string content, string primaryText = "OK", string? secondaryText = null, string? cancelText = null)
    {
        var d = new ContentDialog
        {
            Title = title,
            Content = Content(content),
            PrimaryButtonText = primaryText,
            SecondaryButtonText = secondaryText ?? "",
            CloseButtonText = cancelText ?? "",
            DefaultButton = ContentDialogButton.Primary,
        };
        Style(d);
        return _inner.ShowDialogAsync(d);
    }

    public async Task<bool> ConfirmAsync(string title, string message, string confirmText = "Confirm", string? cancelText = "Cancel") =>
        await ShowAsync(title, message, confirmText, cancelText: cancelText ?? "Cancel") == ContentDialogResult.Primary;

    public Task ShowInfoAsync(string title, string message) => ShowAsync(title, message);

    public Task ShowErrorAsync(string title, string message) => ShowAsync(title, message);

    public Task<ContentDialogResult> ShowDialogAsync(ContentDialog dialog)
    {
        Style(dialog);
        return _inner.ShowDialogAsync(dialog);
    }

    public Task<ContentDialogResult> ShowDialogAsync<T>(object viewModel, string title, string primaryText, string? secondaryText = null, string? cancelText = null)
        where T : UIElement, new() => _inner.ShowDialogAsync<T>(viewModel, title, primaryText, secondaryText, cancelText);
}
