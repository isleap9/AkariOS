using System.IO;
using System.Windows.Controls;
using AkariOS.App.Pages;
using AkariOS.App.Shell;
using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;
using static AkariOS.App.Tests.AppHarness;

namespace AkariOS.App.Tests;

/// <summary>Import / Export settings, through AppHarness: an export from one test PC imports on another.</summary>
[Collection("Motion")]
public sealed class ImportExportTests : IDisposable
{
    private readonly AppHarness _h = new();
    private readonly AppHarness _other = new();

    public void Dispose()
    {
        _h.Dispose();
        _other.Dispose();
    }

    private string File(string name)
    {
        Directory.CreateDirectory(_h.Dir);
        return Path.Combine(_h.Dir, name);
    }

    [Fact]
    public void Export_saves_this_pcs_settings_as_a_preset() => LookTests.OnSta(() =>
    {
        var t = _h.Make(Fixtures());
        Apply(t.S, "fix-plain");
        t.S.Engine.Registry.SetValue(@"HKCU:\Software\AkariFix", "Pick", 3, "DWord");
        t.Picker.SavePath = File("out.json");
        ImportExport.Export(t.S);

        Assert.StartsWith($"AkariOS settings {Environment.MachineName} ", t.Picker.Suggested[0]);
        Assert.Equal($"Exported 2 settings to:\n\n{t.Picker.SavePath}", t.Asked[^1]);
        Assert.Equal(("Ready", false), (t.S.Shell.StatusText, t.S.Shell.Busy));
        var saved = t.S.Engine.Presets.Read(System.IO.File.ReadAllText(t.Picker.SavePath), t.Picker.SavePath, false)!;
        // in file order: Pick.ps1, Plain.ps1
        Assert.Equal(["fix-pick=3", "fix-plain"], saved.Entries.Select(e => e.HasValue ? $"{e.Id}={e.Value}" : e.Id));
        Assert.Contains("\"Exported\"", System.IO.File.ReadAllText(t.Picker.SavePath));
    });

    [Fact]
    public void Cancelling_a_dialog_does_nothing() => LookTests.OnSta(() =>
    {
        var t = _h.Make(Fixtures());
        ImportExport.Export(t.S);
        ImportExport.Import(t.S);
        Assert.Empty(t.Asked);
        Assert.Equal("Home", t.S.Shell.Page);
    });

    [Fact]
    public void An_export_imports_on_another_pc_into_guided_and_quick_select_lists_it() => LookTests.OnSta(() =>
    {
        var from = _h.Make(Fixtures());
        Apply(from.S, "fix-plain");
        from.S.Engine.Registry.SetValue(@"HKCU:\Software\AkariFix", "Pick", 3, "DWord");
        from.Picker.SavePath = File("moved.json");
        ImportExport.Export(from.S);

        var to = _other.Make(Fixtures());
        to.Picker.OpenPath = from.Picker.SavePath;
        ImportExport.Import(to.S);
        Assert.Equal(("Install AkariOS", "Guided", 1, "Tweaks"), (to.S.Shell.Page, to.Install.Mode, to.Install.Step, to.S.Shell.Heading));
        Assert.Equal(["fix-pick Apply 3", "fix-plain Apply "], to.Install.Selection.Values.Select(p => $"{p.Id} {p.Mode} {(p.HasValue ? p.Value : "")}"));
        Assert.True(((CheckBox)to.Install.Tweaks.Rows["fix-plain"].Control).IsChecked);
        // a copy in the presets: Quick select lists it
        Assert.Contains(to.Install.Tweaks.Presets(), p => p.Name == $"Exported from {Environment.MachineName}");
        Assert.True(System.IO.File.Exists(Path.Combine(to.S.Engine.Presets.UserFolder, "moved.json")));
    });

    [Fact]
    public void A_file_with_no_settings_says_so() => LookTests.OnSta(() =>
    {
        var t = _h.Make(Fixtures());
        System.IO.File.WriteAllText(File("empty.json"), """{ "Name": "Empty", "Tweaks": [] }""");
        System.IO.File.WriteAllText(File("junk.json"), "not json");
        foreach (var name in new[] { "empty.json", "junk.json" })
        {
            t.Picker.OpenPath = File(name);
            ImportExport.Import(t.S);
            Assert.Equal($"This file has no AkariOS settings in it:\n\n{t.Picker.OpenPath}", t.Asked[^1]);
        }
        Assert.Equal("Home", t.S.Shell.Page);
    });

    [Fact]
    public void The_home_tile_asks_which_way() => LookTests.OnSta(() =>
    {
        var t = _h.Make(Fixtures());
        t.Answers.Enqueue("Export...");
        ImportExport.Show(t.S);
        Assert.Single(t.Picker.Suggested);
        t.Answers.Enqueue("Cancel");
        ImportExport.Show(t.S);
        Assert.Single(t.Picker.Suggested);
    });

    [Fact]
    public void Quick_select_waits_for_the_states_being_read() => LookTests.OnSta(() =>
    {
        var t = _h.Make(Fixtures());
        // the background holds its work until the test lets it go
        var held = new Queue<Action>();
        var s = new AppServices
        {
            Engine = t.S.Engine, Shell = t.S.Shell, Open = t.S.Open, Log = t.S.Log, Theme = t.S.Theme, Dialogs = t.S.Dialogs,
            Background = (work, done) => held.Enqueue(() => done(work())),
        };
        var install = new InstallPage(s);
        System.IO.File.WriteAllText(File("p.json"), """{ "Name": "P", "Tweaks": [ "fix-plain" ] }""");
        install.GuideTweaks(t.S.Engine.Presets.Read(System.IO.File.ReadAllText(File("p.json")), File("p.json"), false)!);
        Assert.Empty(install.Selection);
        held.Dequeue()();
        Assert.Equal(["fix-plain"], install.Selection.Keys);
    });
}
