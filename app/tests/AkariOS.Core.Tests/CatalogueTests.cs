using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests;

/// <summary>The Catalogue's rules on made-up Tweaks: what the real files don't show (CatalogueOracleTests has those).</summary>
public class CatalogueTests
{
    private static Tweak T(string id, string section, string category, TweakKind kind = TweakKind.Toggle, string? description = null, string[]? requires = null) =>
        new() { Id = id, Name = id, Source = $"src/Tweaks/{section}/{category}/{id}.ps1", Section = section, Category = category, Kind = kind, Description = description, Requires = requires ?? [] };

    [Fact]
    public void Lists_one_file_tweaks_this_pc_meets_outside_Apps_and_OneClick()
    {
        var list = Catalogue.Tweaks([
            T("a", "Optimize", "Gaming"), T("b", "Apps", "Remove"), T("c", "OneClick", "Steps"),
            T("d", "Tools", "Check", TweakKind.Action), T("e", "Optimize", "Gaming", requires: ["Win10"]),
            T("f", "Hardware", "Graphics", requires: ["Win11"]),
        ], new FakeSystem());
        Assert.Equal(["a", "d", "f"], list.Select(t => t.Id));
    }

    [Fact]
    public void Known_sections_first_then_the_others_by_name_and_categories_by_name()
    {
        var pages = Catalogue.Pages([
            T("1", "Zeta", "B"), T("2", "Hardware", "Input"), T("3", "Optimize", "Power"), T("4", "Alpha", "x"),
            T("5", "Optimize", "gaming"), T("6", "Optimize", "Power"),
        ]);
        Assert.Equal(["Optimize", "Hardware", "Alpha", "Zeta"], pages.Select(s => s.Section));
        Assert.Equal("Graphics & Hardware", pages[1].Header);
        Assert.Equal(["Catalogue:Optimize/gaming", "Catalogue:Optimize/Power"], pages[0].Pages.Select(p => p.Key));
    }

    [Fact]
    public void Search_looks_in_name_and_description_as_a_wildcard_in_page_order()
    {
        var list = new[] { T("Late power", "Customize", "System"), T("Early", "Optimize", "Power", description: "a Power plan"), T("Other", "Optimize", "Gaming") };
        Assert.Equal(["Early", "Late power"], Catalogue.List(list, "", "power").Select(t => t.Id));
        Assert.Equal(["Early"], Catalogue.List(list, "", "power*plan").Select(t => t.Id));
        Assert.Equal(["Other"], Catalogue.List(list, "Catalogue:Optimize/Gaming", "").Select(t => t.Id));
    }

    [Theory]
    [InlineData("Catalogue:Advanced/Scheduled tasks", "Advanced", "Scheduled tasks")]
    [InlineData("Catalogue:Optimize/A/B", "Optimize", "A/B")]
    public void A_key_splits_into_section_and_category(string key, string section, string category) =>
        Assert.Equal((section, category), Catalogue.Split(key));

    [Theory]
    [InlineData("Optimize")]
    [InlineData("Catalogue:NoCategory")]
    public void Other_pages_are_no_catalogue_key(string key) => Assert.Null(Catalogue.Split(key));

    [Theory]
    [InlineData(0, 0, new string[0])]
    [InlineData(1, 0, new[] { "Explorer needs a restart to show 1 change." })]
    [InlineData(2, 1, new[] { "Explorer needs a restart to show 2 changes.", "A restart finishes 1 change." })]
    [InlineData(0, 3, new[] { "A restart finishes 3 changes." })]
    public void Restart_bar_lines(int explorer, int reboot, string[] lines) => Assert.Equal(lines, Catalogue.RestartBarText(explorer, reboot));

    [Theory]
    [InlineData(TweakKind.Toggle, TweakState.Optimized, CatalogueBusy.None, false, "Optimized")]
    [InlineData(TweakKind.Toggle, TweakState.Default, CatalogueBusy.None, false, "Windows default")]
    [InlineData(TweakKind.Choice, TweakState.Custom, CatalogueBusy.None, false, "Custom value")]
    [InlineData(TweakKind.Toggle, TweakState.Unknown, CatalogueBusy.None, false, "State unknown")]
    [InlineData(TweakKind.Action, TweakState.Unknown, CatalogueBusy.None, false, "")]
    [InlineData(TweakKind.Toggle, TweakState.Default, CatalogueBusy.None, true, "Waiting for Safe Mode")]
    [InlineData(TweakKind.Action, TweakState.Unknown, CatalogueBusy.Reading, false, "Reading…")]
    [InlineData(TweakKind.Toggle, TweakState.Default, CatalogueBusy.Waiting, true, "Waiting…")]
    [InlineData(TweakKind.Toggle, TweakState.Default, CatalogueBusy.Running, false, "Applying…")]
    public void State_lines(TweakKind kind, TweakState state, CatalogueBusy busy, bool safe, string text) =>
        Assert.Equal(text, Catalogue.StateText(T("x", "Optimize", "Gaming", kind), state, busy, safe));

    [Fact]
    public void A_safe_mode_change_waits_unless_it_is_where_it_already_is()
    {
        var pending = new Dictionary<string, SafeChange>();
        var t = T("x", "Advanced", "Security");
        Catalogue.SetSafePending(pending, t, TweakState.Default, TweakMode.Apply);
        Assert.Equal(new SafeChange(TweakMode.Apply, null), pending["x"]);
        // switched back before the restart: nothing waits
        Catalogue.SetSafePending(pending, t, TweakState.Default, TweakMode.Revert);
        Assert.Empty(pending);
        Catalogue.SetSafePending(pending, t, TweakState.Optimized, TweakMode.Apply);
        Assert.Empty(pending);
        // a Choice value: waits unless the value is already there
        Catalogue.SetSafePending(pending, t, TweakState.Custom, TweakMode.Apply, 3, 2);
        Assert.Equal(new SafeChange(TweakMode.Apply, 3), pending["x"]);
        Catalogue.SetSafePending(pending, t, TweakState.Custom, TweakMode.Apply, 2, 2);
        Assert.Empty(pending);
        Assert.Equal("1 change needs Safe Mode: Akari restarts into it, applies them and restarts back.", Catalogue.SafeBarText(1));
        Assert.Equal("2 changes need Safe Mode: Akari restarts into it, applies them and restarts back.", Catalogue.SafeBarText(2));
    }

    [Fact]
    public void Where_a_guided_row_starts()
    {
        var toggle = T("t", "Optimize", "Gaming");
        var choice = new Tweak { Id = "c", Name = "c", Source = "src/Tweaks/Optimize/Gaming/c.ps1", Section = "Optimize", Category = "Gaming", Kind = TweakKind.Choice,
            Choices = [new ChoiceValue(1, "One", null), new ChoiceValue(2, "Two", null)] };
        Assert.Equal(Selection.Optimized, Selection.RowStart(toggle, TweakState.Optimized, null, true));
        Assert.Equal(Selection.None, Selection.RowStart(toggle, TweakState.Optimized, null, false));
        Assert.Equal(Selection.None, Selection.RowStart(toggle, TweakState.Custom, null, true));
        Assert.Equal(2, Selection.RowStart(choice, TweakState.Custom, 2, true));
        Assert.Equal(Selection.None, Selection.RowStart(choice, TweakState.Custom, 7, true));
        Assert.Equal(Selection.None, Selection.RowStart(T("a", "Optimize", "Gaming", TweakKind.Action), TweakState.Unknown, null, true));
    }

    [Theory]
    [InlineData(true, "None", "Optimized")]
    [InlineData(true, "Optimized", "Optimized")]
    [InlineData(false, "Optimized", "Default")]
    [InlineData(false, "None", "None")]
    public void A_checkbox_target(bool isChecked, string initial, string target) => Assert.Equal(target, Selection.CheckTarget(isChecked, initial));

    [Fact]
    public void Masonry_puts_each_card_in_the_shortest_column() =>
        // each card adds its size + 2: after three cards the columns hold 5, 3, 4, so the 4th goes in column 1 (7),
        // the 5th in column 2 (4 is now the shortest)
        Assert.Equal([0, 1, 2, 1, 2], Selection.Masonry([3, 1, 2, 2, 1], 3));

    [Fact]
    public void The_restart_note_and_the_run_summary()
    {
        var restarts = new Tweak { Id = "r", Name = "Restarter", Source = "src/Tweaks/Optimize/Gaming/r.ps1", Section = "Optimize", Category = "Gaming", Restarts = true };
        var other = new Tweak { Id = "q", Name = "Other", Source = "src/Tweaks/Optimize/Gaming/q.ps1", Section = "Optimize", Category = "Gaming", Restarts = true };
        var plain = T("p", "Optimize", "Gaming");
        var find = new Dictionary<string, Tweak> { ["r"] = restarts, ["q"] = other, ["p"] = plain };
        Pending P(string id, TweakMode mode = TweakMode.Apply) => new(id, find[id].Name, mode, null, false, "", "");
        Assert.Null(Selection.RestartNote([P("p")], find.GetValueOrDefault));
        // a Revert doesn't restart
        Assert.Null(Selection.RestartNote([P("r", TweakMode.Revert)], find.GetValueOrDefault));
        Assert.Equal("Restarter restarts the PC (into Safe Mode for some), so it runs last, after every other change.", Selection.RestartNote([P("p"), P("r")], find.GetValueOrDefault));
        Assert.Equal("These restart the PC: Restarter, Other. Only Restarter runs now, last; the others are skipped: select them again after the restart.",
            Selection.RestartNote([P("r"), P("q")], find.GetValueOrDefault));

        Assert.Equal(("2 applied, 1 already, 1 failed", true), Selection.RunSummary([
            new("a", TweakMode.Apply, OutcomeKind.Failed), new("b", TweakMode.Apply, OutcomeKind.Applied, Reboot: true),
            new("c", TweakMode.Apply, OutcomeKind.Already), new("d", TweakMode.Apply, OutcomeKind.Applied)]));
        Assert.Equal(("", false), Selection.RunSummary([]));
    }
}
