using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Shapes;
using AkariOS.App.Look;
using AkariOS.Core;

namespace AkariOS.App.Shell;

/// <summary>A dialog's icon (a Lucide name), its colour and its blob's fill: Info, Question, Warning, Error, None.</summary>
public sealed record DialogIcon(string Glyph, string Brush, string Fill)
{
    public static IReadOnlyDictionary<string, DialogIcon> All { get; } = new Dictionary<string, DialogIcon>
    {
        ["Info"] = new("info", "AccText", "AccSoft"),
        ["Question"] = new("circle-help", "AccText", "AccSoft"),
        ["Warning"] = new("triangle-alert", "Warn", "WarnSoft"),
        ["Error"] = new("circle-x", "Bad", "AccSoft"),
    };
}

/// <summary>
/// Akari's dialogs (src/UI/Dialog.ps1), from the shared src/UI/Dialog.xaml as it is: a dark card over the dimmed
/// window, an icon blob beside the Unbounded title, buttons that say what they do, the last one the crimson main
/// action (Enter), the first one Esc. Windows' message box only if Akari's can't open (the crash box stays native).
/// </summary>
public sealed class Dialogs(Func<ResourceDictionary> resources, IAkariLog log)
{
    /// <summary>Shows a built dialog and waits (tests replace it: nothing is shown there).</summary>
    public Func<Window, string?> Runner { get; init; } = null!;

    /// <summary>Windows' own box, when Akari's can't open (tests replace it).</summary>
    public Func<string, string, IReadOnlyList<string>, string, string?> Fallback { get; init; } = NativeBox;

    private sealed class State
    {
        public string? Result;
    }

    /// <summary>Builds a dialog without showing it; its Tag holds the pressed button's text (null = closed).</summary>
    public Window Build(string message, string title = "AkariOS", IReadOnlyList<string>? buttons = null, string icon = "Info", bool textBox = false)
    {
        buttons ??= ["OK"];
        var d = (Window)AkariXaml.Load("Dialog.xaml", Motion.On);
        d.Resources.MergedDictionaries.Add(resources());
        var state = new State();
        d.Tag = state;
        ((TextBlock)d.FindName("DlgTitle")).Text = title;
        ((TextBlock)d.FindName("DlgText")).Text = message;
        var blob = (Border)d.FindName("DlgIcon");
        if (DialogIcon.All.TryGetValue(icon, out var i))
        {
            var p = (Path)d.FindName("DlgIconPath");
            p.SetResourceReference(Path.DataProperty, $"Ic.{i.Glyph}");
            p.SetResourceReference(Shape.StrokeProperty, i.Brush);
            blob.SetResourceReference(Border.BackgroundProperty, i.Fill);
            blob.Tag = i.Glyph;
        }
        else blob.Visibility = Visibility.Collapsed;
        var input = (TextBox)d.FindName("DlgInput");
        if (textBox) input.Visibility = Visibility.Visible;
        var bar = (StackPanel)d.FindName("DlgButtons");
        for (var n = 0; n < buttons.Count; n++)
        {
            var main = n == buttons.Count - 1;
            var b = new Button { Content = buttons[n], Tag = buttons[n], MinWidth = 88, Margin = new Thickness(n > 0 ? 8 : 0, 0, 0, 0), IsDefault = main, IsCancel = n == 0 };
            // the main action crimson (BtnP), the others ghost: the secondary pill with no fill or stroke until hover
            b.SetResourceReference(FrameworkElement.StyleProperty, main ? "BtnP" : "Btn");
            if (!main) { b.Background = Brushes.Transparent; b.BorderBrush = Brushes.Transparent; }
            b.Click += (_, _) => { state.Result = (string)b.Tag; d.Close(); };
            bar.Children.Add(b);
        }
        // the title drags the dialog; the text box takes the focus
        ((TextBlock)d.FindName("DlgTitle")).MouseLeftButtonDown += (_, e) => { if (e.ButtonState == MouseButtonState.Pressed) try { d.DragMove(); } catch (InvalidOperationException) { } };
        d.ContentRendered += (_, _) => { if (textBox) input.Focus(); };
        return d;
    }

    /// <summary>The pressed button's text of a built dialog (after it closed).</summary>
    public static string? Result(Window dialog) => ((State)dialog.Tag).Result;

    /// <summary>Shows a built dialog over the dimmed window and waits: the pressed button's text, or null.</summary>
    public static string? ShowOver(Window dialog, Window? owner, UIElement? overlay)
    {
        if (owner is { IsVisible: true }) dialog.Owner = owner;
        else dialog.WindowStartupLocation = WindowStartupLocation.CenterScreen;
        // the dim fades in and out; the card pops in once the dialog has loaded
        if (overlay != null) Motion.Show(overlay, null, "Fast");
        dialog.Loaded += (_, _) => Motion.Start(dialog.Content as UIElement, MotionKind.Pop, speed: "Slow");
        try { dialog.ShowDialog(); }
        finally { if (overlay != null) Motion.Hide(overlay); }
        return Result(dialog);
    }

    /// <summary>A dialog: the pressed button's text, or null (closed). Windows' box stands in if it can't open.</summary>
    public string? Show(string message, string title = "AkariOS", IReadOnlyList<string>? buttons = null, string icon = "Info")
    {
        buttons ??= ["OK"];
        try { return Runner(Build(message, title, buttons, icon)); }
        catch (Exception e) when (e is not OutOfMemoryException)
        {
            log.WriteFile($"Dialog: {e.Message}");
            return Fallback(message, title, buttons, icon);
        }
    }

    /// <summary>Yes / No in words: true when the main action was pressed.</summary>
    public bool Confirm(string message, string yes, string no = "Cancel", string icon = "Warning", string title = "AkariOS") =>
        Show(message, title, [no, yes], icon) == yes;

    /// <summary>A message with one OK button.</summary>
    public void Message(string message, string icon = "Info", string title = "AkariOS") => Show(message, title, ["OK"], icon);

    /// <summary>Asks for a line of text: the trimmed text, or null (cancelled or empty).</summary>
    public string? ReadText(string prompt, string ok = "OK", string title = "AkariOS")
    {
        string? pressed, text;
        try
        {
            var d = Build(prompt, title, ["Cancel", ok], "None", textBox: true);
            pressed = Runner(d);
            text = ((TextBox)d.FindName("DlgInput")).Text;
        }
        catch (Exception e) when (e is not OutOfMemoryException)
        {
            log.WriteFile($"Dialog: {e.Message}");
            return null;
        }
        return pressed == ok && !string.IsNullOrWhiteSpace(text) ? text.Trim() : null;
    }

    private static string? NativeBox(string message, string title, IReadOnlyList<string> buttons, string icon)
    {
        var image = icon switch { "Error" => MessageBoxImage.Error, "Warning" => MessageBoxImage.Warning, "Question" => MessageBoxImage.Question, _ => MessageBoxImage.Information };
        if (buttons.Count < 2) { MessageBox.Show(message, title, MessageBoxButton.OK, image); return buttons[0]; }
        return MessageBox.Show(message, title, MessageBoxButton.YesNo, image) == MessageBoxResult.Yes ? buttons[^1] : buttons[0];
    }

    /// <summary>The app's dialogs: over its window, dimming its ModalOverlay.</summary>
    public static Dialogs For(MainWindow window, IAkariLog log) =>
        new(() => window.Resources, log) { Runner = d => ShowOver(d, window, window.ModalOverlay) };
}
