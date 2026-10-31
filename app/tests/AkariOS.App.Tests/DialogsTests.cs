using System.Windows;
using System.Windows.Controls;
using AkariOS.App.Look;
using AkariOS.App.Shell;
using AkariOS.Core;

namespace AkariOS.App.Tests;

/// <summary>The dialogs, built but never shown: the runner presses a button instead of a person.</summary>
[Collection("Motion")]
public sealed class DialogsTests
{
    private static ResourceDictionary Resources()
    {
        var r = new ResourceDictionary();
        foreach (var d in AkariXaml.SharedResources("Dark", false)) r.MergedDictionaries.Add(d);
        Assets.AddFonts(r);
        return r;
    }

    private static void Press(Window d, string text) =>
        ((StackPanel)d.FindName("DlgButtons")).Children.OfType<Button>().Single(b => (string)b.Content == text)
            .RaiseEvent(new RoutedEventArgs(System.Windows.Controls.Primitives.ButtonBase.ClickEvent));

    private static Dialogs Make(Func<Window, string?> runner, MemoryLog? log = null, Func<string, string, IReadOnlyList<string>, string, string?>? fallback = null) =>
        new(Resources, log ?? new MemoryLog()) { Runner = runner, Fallback = fallback ?? ((_, _, b, _) => throw new InvalidOperationException("no native box in a test")) };

    [Fact]
    public void Builds_the_shared_dialog() => LookTests.OnSta(() =>
    {
        Motion.Initialize(false);
        var dialogs = Make(_ => null);
        var d = dialogs.Build("Remove 12 apps?", "Remove apps", ["Keep them", "Remove"], "Warning");
        Assert.Equal("Remove apps", ((TextBlock)d.FindName("DlgTitle")).Text);
        Assert.Equal("Remove 12 apps?", ((TextBlock)d.FindName("DlgText")).Text);
        Assert.Equal("triangle-alert", ((Border)d.FindName("DlgIcon")).Tag);
        var buttons = ((StackPanel)d.FindName("DlgButtons")).Children.OfType<Button>().ToList();
        Assert.Equal(["Keep them", "Remove"], buttons.Select(b => (string)b.Content));
        Assert.Equal((true, false), (buttons[0].IsCancel, buttons[0].IsDefault));
        Assert.Equal((false, true), (buttons[1].IsCancel, buttons[1].IsDefault));
        Assert.Equal(Visibility.Collapsed, ((TextBox)d.FindName("DlgInput")).Visibility);

        Press(d, "Remove");
        Assert.Equal("Remove", Dialogs.Result(d));
    });

    [Fact]
    public void No_icon_and_a_text_box() => LookTests.OnSta(() =>
    {
        Motion.Initialize(false);
        var d = Make(_ => null).Build("Name this preset", buttons: ["Cancel", "Save"], icon: "None", textBox: true);
        Assert.Equal(Visibility.Collapsed, ((Border)d.FindName("DlgIcon")).Visibility);
        Assert.Equal(Visibility.Visible, ((TextBox)d.FindName("DlgInput")).Visibility);
        Assert.Null(Dialogs.Result(d));
    });

    [Fact]
    public void Confirm_message_and_text() => LookTests.OnSta(() =>
    {
        Motion.Initialize(false);
        Assert.True(Make(d => { Press(d, "Restart"); return Dialogs.Result(d); }).Confirm("Restart now?", "Restart"));
        Assert.False(Make(d => { Press(d, "Cancel"); return Dialogs.Result(d); }).Confirm("Restart now?", "Restart"));
        Assert.False(Make(_ => null).Confirm("Restart now?", "Restart"));
        Make(d => { Press(d, "OK"); return Dialogs.Result(d); }).Message("Done");

        string? Type(string typed, string press) => Make(d =>
        {
            ((TextBox)d.FindName("DlgInput")).Text = typed;
            Press(d, press);
            return Dialogs.Result(d);
        }).ReadText("Name this preset", "Save");
        Assert.Equal("My preset", Type("  My preset ", "Save"));
        Assert.Null(Type("My preset", "Cancel"));
        Assert.Null(Type("   ", "Save"));
    });

    [Fact]
    public void Windows_box_stands_in_when_akaris_cant_open() => LookTests.OnSta(() =>
    {
        Motion.Initialize(false);
        var log = new MemoryLog();
        var asked = new List<string>();
        var dialogs = Make(_ => throw new InvalidOperationException("no owner"), log, (m, _, b, _) => { asked.Add(m); return b[^1]; });
        Assert.True(dialogs.Confirm("Go?", "Go"));
        Assert.Equal(["Go?"], asked);
        Assert.Contains(log.FileLines, l => l == "Dialog: no owner");
    });

    [Fact]
    public void Every_dialog_icon_is_in_Icons_xaml()
    {
        var icons = AkariXaml.Text("Icons.xaml");
        Assert.All(DialogIcon.All.Values, i => Assert.Contains($"x:Key=\"Ic.{i.Glyph}\"", icons));
    }
}
