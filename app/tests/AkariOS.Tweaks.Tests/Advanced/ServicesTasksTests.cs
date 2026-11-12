using System.Text.Json;
using AkariOS.Core.Machine;
using AkariOS.Core.Runs;
using AkariOS.Core.Tests;
using AkariOS.Core.Tweaks;
using AkariOS.Tweaks.Advanced.Services;
using static AkariOS.Tweaks.Tests.BlockLines;

namespace AkariOS.Tweaks.Tests.Advanced;

/// <summary>N6: advanced-services-off (a Choice over services.psd1's start types) and advanced-remove-scheduled-tasks
/// against their PowerShell blocks (Oracle/Invoke-TweakBlocks.ps1) on a test key and fakes.</summary>
public sealed class ServicesTasksTests : IDisposable
{
    private readonly TweakHarness _h = new();

    public void Dispose() => _h.Dispose();

    private JsonElement Blocks(string id, params string[] more) =>
        Oracle.Run("Invoke-TweakBlocks.ps1", ["-Src", Repo.Src, "-Ids", id, "-TestRoot", _h.KeyRoot, .. more]);

    private const string Id = "advanced-services-off";
    private const string Root = @"HKLM:\SYSTEM\CurrentControlSet\Services";

    // a few services of services.psd1 on this "PC", each at its Windows default (AJRouter 3, BFE 2, BITS 2, Spooler 2),
    // and one it doesn't know
    private void Services()
    {
        foreach (var (n, v) in new[] { ("AJRouter", 3), ("BFE", 2), ("BITS", 2), ("Spooler", 2), ("Contoso", 3) })
            _h.Set($@"{Root}\{n}", "Start", v, "DWord");
    }

    private static List<string> PsRows(IEnumerable<string> lines, string kind) =>
        lines.Where(l => l.StartsWith($"{kind} Apply ", StringComparison.Ordinal)).Select(l => l[(kind.Length + 7)..]).ToList();

    private List<string> CsRows(string pick) => ServicesOff.Rows(_h.Tweak(Id), _h.Engine.Context, pick)
        .Select(r => $"{r.Path}|{r.Name}|{r.Value}|{r.Default.For(26100)}").ToList();

    [Theory]
    [InlineData("Off")]
    [InlineData("Light")]
    [InlineData("Manual")]
    public void A_pick_writes_the_same_rows_as_trustedinstaller_then_as_admin(string pick)
    {
        Services();
        var ps = Blocks(Id, "-Value", pick);
        Assert.Equal("Default", Lines(ps, Id, "Value").Single()[7..]);
        Assert.Equal("Default", _h.Engine.States.ChoiceValue(_h.Tweak(Id)));
        var apply = Lines(ps, Id, "Apply");
        Assert.Equal(PsRows(apply, "trusted"), CsRows(pick));
        Assert.Equal(PsRows(apply, "registry"), CsRows(pick));
        Assert.Equal(4, CsRows(pick).Count);

        var trustedRuns = _h.Trusted.Runs;
        _h.Engine.Codes[Id].Apply(_h.Tweak(Id), _h.Engine.Context, pick);
        Assert.Equal(trustedRuns + 1, _h.Trusted.Runs);
        Assert.Equal(pick, _h.Engine.States.ChoiceValue(_h.Tweak(Id)));
        Assert.Equal($"result {pick}", Lines(Blocks(Id), Id, "Value").Single());

        Assert.Equal(OutcomeKind.Reverted, _h.Run(Id, TweakMode.Revert).Kind);
        Assert.Equal("Default", _h.Engine.States.ChoiceValue(_h.Tweak(Id)));
    }

    [Fact]
    public void A_start_type_changed_by_hand_is_none_of_the_picks()
    {
        Services();
        _h.Set($@"{Root}\BITS", "Start", 4, "DWord");
        Assert.Equal("result ", Lines(Blocks(Id), Id, "Value").Single());
        Assert.Null(_h.Engine.States.ChoiceValue(_h.Tweak(Id)));
    }

    [Fact]
    public void Removing_every_task_keeps_text_input_and_svcrestarttask_and_counts_what_went()
    {
        foreach (var n in new[] { "SvcRestartTask", "MsCtfMonitor", "MapsUpdateTask", "GoogleUpdateTaskMachineUA", "Schedule Scan" })
            _h.Tasks.All[new ScheduledTask(n == "GoogleUpdateTaskMachineUA" ? @"\" : @"\Microsoft\Windows\X", n)] = true;
        _h.Tasks.Kept.Add("Schedule Scan");
        var ps = Lines(Blocks("advanced-remove-scheduled-tasks", "-Tasks", string.Join(";", _h.Tasks.All.Keys.Select(t => $"{t.Folder}\\|{t.Name}")), "-KeptTasks", "Schedule Scan"),
            "advanced-remove-scheduled-tasks", "Apply");
        Assert.Equal(OutcomeKind.Applied, _h.Run("advanced-remove-scheduled-tasks", TweakMode.Apply).Kind);
        Assert.Equal(Of(ps, "unregister").Select(l => l.Split('|')[1]).Order(), _h.Tasks.Unregistered.Select(t => t.Name).Order());
        Assert.Equal(["MapsUpdateTask", "GoogleUpdateTaskMachineUA"], _h.Tasks.Unregistered.Select(t => t.Name).Order().Reverse());
        Assert.Equal("said Removed 2 scheduled tasks", ps[^1]);
        Assert.Contains("Removed 2 scheduled tasks", _h.Log.Lines);
    }
}
