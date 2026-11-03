using System.Text.Json;
using AkariOS.Core.Data;
using AkariOS.Core.Runs;
using AkariOS.Core.Tests;
using AkariOS.Core.Tweaks;
using AkariOS.Tweaks.Customize.ContextMenu;

namespace AkariOS.Tweaks.Tests.Customize;

/// <summary>Customize › Context menu (g7) on a test key. The seven files that build their rows with code are checked by
/// the rows oracle (OptimizeTests, every RowsAreCode class); here the block Tweaks are compared with the PowerShell
/// blocks run with recorders (Oracle/Invoke-TweakBlocks.ps1), their key reads on the same test key.</summary>
public sealed class ContextMenuTests : IDisposable
{
    private readonly TweakHarness _h = new();

    public void Dispose() => _h.Dispose();

    private const string Classes = @"HKLM:\SOFTWARE\Classes";

    private JsonElement Blocks(string ids) => Oracle.Run("Invoke-TweakBlocks.ps1", "-Src", Repo.Src, "-Ids", ids, "-TestRoot", _h.KeyRoot);

    private static List<string> Lines(JsonElement e, string id, string block, string prefix) =>
        e.GetProperty(id).GetProperty(block).EnumerateArray().Select(l => l.GetString()!)
            .Where(l => l.StartsWith(prefix, StringComparison.Ordinal)).Select(l => l[prefix.Length..]).ToList();

    private static string Row(RegistryRow r) =>
        $"{r.Path}|{r.Name}|{PsSemantics.Text(r.Value)}|{PsSemantics.Text(r.Default.For(26100))}";

    [Fact]
    public void Every_g7_tweak_is_native_now() => Assert.All(
        TweakHarness.All.Where(t => t.Section == "Customize" && t.Category == "Context menu"),
        t => Assert.Null(Runner.NotNative(_h.Tweak(t.Id))));

    [Fact]
    public void The_rows_check_covers_the_files_that_build_rows_with_code()
    {
        string[] ids = ["context-add-legacy-settings", "context-add-new-files", "context-add-powershell-cmd", "context-add-ps1-options",
            "context-add-run-as-admin", "context-add-take-ownership", "context-remove-extract-all"];
        Assert.All(ids, id => Assert.True(_h.Tweak(id).RowsAreCode && _h.Tweak(id).Code is not null, id));
    }

    [Fact]
    public void A_row_script_tweak_applies_and_reverts_its_rows()
    {
        const string id = "context-add-ps1-options";
        var rows = _h.Tweak(id).Code!.Rows(_h.Tweak(id), _h.Engine.Context);
        Assert.Contains(rows, r => r.Name == "CommandFlags" && PsSemantics.LooseEquals(r.Value, 0x20));
        Assert.Equal(TweakState.Default, _h.State(id));
        Assert.Equal(OutcomeKind.Applied, _h.Run(id, TweakMode.Apply).Kind);
        Assert.Equal(TweakState.Optimized, _h.State(id));
        Assert.Equal(OutcomeKind.Reverted, _h.Run(id, TweakMode.Revert).Kind);
        Assert.False(_h.Engine.Registry.KeyExists($@"{Classes}\SystemFileAssociations\.ps1\Shell\run_edit"));
    }

    [Fact]
    public void The_desktop_menu_entries_are_hidden_as_trustedinstaller_with_the_powershell_blocks_rows()
    {
        string[] ids = ["context-remove-display", "context-remove-personalize"];
        var ps = Blocks(string.Join(",", ids));
        foreach (var id in ids)
        {
            var t = _h.Tweak(id);
            Assert.Equal(Lines(ps, id, "Detect", "row "), TrustedRows.Of(t, "Detect").Select(Row));
            Assert.Equal(Lines(ps, id, "Apply", "trusted Apply "), TrustedRows.Of(t, "Apply").Select(Row));
            Assert.Equal(Lines(ps, id, "Revert", "trusted Revert "), TrustedRows.Of(t, "Revert").Select(Row));

            var key = TrustedRows.Of(t, "Apply").Single().Path;
            var runs = _h.Trusted.Runs;
            Assert.Equal(OutcomeKind.Applied, _h.Run(id, TweakMode.Apply).Kind);
            Assert.Equal("", _h.Get(key, "ProgrammaticAccessOnly"));
            Assert.Equal(TweakState.Optimized, _h.State(id));
            Assert.Equal(OutcomeKind.Reverted, _h.Run(id, TweakMode.Revert).Kind);
            Assert.Null(_h.Get(key, "ProgrammaticAccessOnly"));
            Assert.True(_h.Trusted.Runs >= runs + 2, id);
        }
    }

    [Fact]
    public void Print_touches_only_the_verbs_this_windows_has_as_the_powershell_helper_does()
    {
        const string id = "context-remove-print";
        var t = _h.Tweak(id);
        Assert.Empty(RemovePrint.Verbs(t, _h.Engine.Context));
        Assert.Equal(TweakState.Unknown, _h.State(id));

        foreach (var v in new[] { @"txtfile\shell\print", @"SystemFileAssociations\image\shell\print", @"VBSFile\Shell\Print" })
            _h.Engine.Registry.CreateKey($@"{Classes}\{v}");
        var verbs = RemovePrint.Verbs(t, _h.Engine.Context);
        Assert.Equal(3, verbs.Count);
        var ps = Blocks(id);
        Assert.Equal(Lines(ps, id, "Detect", "row "), verbs.Select(Row));
        Assert.Equal(Lines(ps, id, "Apply", "registry Apply "), verbs.Select(Row));
        Assert.Equal(Lines(ps, id, "Revert", "registry Revert "), verbs.Select(Row));

        Assert.Equal(TweakState.Default, _h.State(id));
        Assert.Equal(OutcomeKind.Applied, _h.Run(id, TweakMode.Apply).Kind);
        Assert.Equal(TweakState.Optimized, _h.State(id));
        Assert.Equal(OutcomeKind.Reverted, _h.Run(id, TweakMode.Revert).Kind);
        Assert.Equal(TweakState.Default, _h.State(id));
    }
}
