using System.Text.Json;
using AkariOS.Core.Runs;
using AkariOS.Core.Tests;
using AkariOS.Core.Tweaks;
using static AkariOS.Tweaks.Tests.BlockLines;

namespace AkariOS.Tweaks.Tests;

/// <summary>winutil W3's script-block Tweaks outside Network (the Store's search database, the Logitech assistant,
/// reserved storage, the component cleanup) against their PowerShell blocks (Oracle/Invoke-TweakBlocks.ps1): the same
/// States, deny rules, processes stopped, files deleted and DISM calls.</summary>
public sealed class WinutilTests : IDisposable
{
    private readonly TweakHarness _h = new();
    private const string Store = "apps-store-no-search-ads";
    private const string Logi = "update-block-logitech-assistant";
    private const string StoreDb = @"Packages\Microsoft.WindowsStore_8wekyb3d8bbwe\LocalState\store.db";

    public void Dispose() => _h.Dispose();

    // ---- the Store's search database (the real user's Local AppData)

    private string Local()
    {
        var p = _h.Folder(@"User\AppData\Local");
        _h.Set(@"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders", "Local AppData", p, "String");
        return p;
    }

    private JsonElement StoreBlocks(string local, string denied = ";") => Oracle.Run("Invoke-TweakBlocks.ps1",
        "-Src", Repo.Src, "-Ids", Store, "-UserFolder", local, "-Denied", denied);

    private List<string> CsDeny(string root, string name) =>
        _h.Acl.Calls.Select(c => c.Replace(root, name, StringComparison.OrdinalIgnoreCase)).ToList();

    [Fact]
    public void The_store_tweak_is_unknown_and_fails_the_same_without_a_search_database()
    {
        var local = Local();
        var ps = StoreBlocks(local);
        Assert.Equal("Unknown", Result(ps, Store));
        Assert.Equal(TweakState.Unknown, _h.State(Store));
        var o = _h.Run(Store, TweakMode.Apply);
        Assert.Equal((OutcomeKind.Failed, Lines(ps, Store, "Apply").Last()[6..]), (o.Kind, o.Message));
        Assert.Empty(_h.Acl.Calls);
    }

    [Fact]
    public void The_store_tweak_denies_the_same_data_and_reads_it_back()
    {
        var local = Local();
        var db = Path.Combine(local, StoreDb);
        Directory.CreateDirectory(Path.GetDirectoryName(db)!);
        File.WriteAllText(db, "x");

        var ps = StoreBlocks(local);
        Assert.Equal("Default", Result(ps, Store));
        Assert.Equal(TweakState.Default, _h.State(Store));
        Assert.Equal(OutcomeKind.Applied, _h.Run(Store, TweakMode.Apply).Kind);
        Assert.Equal(Of(Lines(ps, Store, "Apply"), "deny"), CsDeny(local, "%User%"));

        var on = StoreBlocks(local, $@"%User%\{StoreDb}=7");
        Assert.Equal("Optimized", Result(on, Store));
        Assert.Equal(TweakState.Optimized, _h.State(Store));

        _h.Acl.Calls.Clear();
        Assert.Equal(OutcomeKind.Reverted, _h.Run(Store, TweakMode.Revert).Kind);
        Assert.Equal(Of(Lines(on, Store, "Revert"), "deny"), CsDeny(local, "%User%"));
        Assert.Equal(TweakState.Default, _h.State(Store));

        // someone else's rule: neither Optimized nor Default
        _h.Acl.Deny[db] = 1;
        Assert.Equal("Custom", Result(StoreBlocks(local, $@"%User%\{StoreDb}=1"), Store));
        Assert.Equal(TweakState.Custom, _h.State(Store));
    }

    // ---- the Logitech assistant (its own Program Files copy on each side)

    private JsonElement LogiBlocks(string pf, string denied = ";") => Oracle.Run("Invoke-TweakBlocks.ps1",
        "-Src", Repo.Src, "-Ids", Logi, "-ProgramFiles", pf, "-Denied", denied);

    private static void Assistant(string pf)
    {
        Directory.CreateDirectory(Path.Combine(pf, @"LogiDownloadAssistant\sub"));
        File.WriteAllText(Path.Combine(pf, @"LogiDownloadAssistant\logi_download_assistant.exe"), "x");
    }

    [Theory]
    [InlineData(true)]
    [InlineData(false)]
    public void The_logitech_block_empties_and_locks_the_same_folder(bool there)
    {
        var psPf = _h.Folder("PS Program Files");
        var cs = _h.Engine.Services.ProgramFiles;
        if (there) { Assistant(psPf); Assistant(cs); }

        var ps = LogiBlocks(psPf);
        Assert.Equal("Default", Result(ps, Logi));
        Assert.Equal(TweakState.Default, _h.State(Logi));
        var apply = Lines(ps, Logi, "Apply").Select(l => l.Replace("%ProgramFiles%", "%PF%")).ToList();

        Assert.Equal(OutcomeKind.Applied, _h.Run(Logi, TweakMode.Apply).Kind);
        Assert.Equal(Of(apply, "stop"), _h.Processes.Stopped.Select(p => $"stop {p}").ToList());
        Assert.Equal(Of(apply, "deny"), CsDeny(cs, "%PF%"));
        var folder = Path.Combine(cs, "LogiDownloadAssistant");
        Assert.Empty(Directory.EnumerateFileSystemEntries(folder));
        Assert.Empty(Directory.EnumerateFileSystemEntries(Path.Combine(psPf, "LogiDownloadAssistant")));
        Assert.Equal(there ? 2 : 0, Of(apply, "delete").Count);

        var on = LogiBlocks(psPf, @"%ProgramFiles%\LogiDownloadAssistant=278");
        Assert.Equal("Optimized", Result(on, Logi));
        Assert.Equal(TweakState.Optimized, _h.State(Logi));

        _h.Acl.Calls.Clear();
        Assert.Equal(OutcomeKind.Reverted, _h.Run(Logi, TweakMode.Revert).Kind);
        Assert.Equal(Of(Lines(on, Logi, "Revert").Select(l => l.Replace("%ProgramFiles%", "%PF%")), "deny"), CsDeny(cs, "%PF%"));
        Assert.True(Directory.Exists(folder));
        Assert.Equal(TweakState.Default, _h.State(Logi));
    }

    // ---- DISM: reserved storage and the component store

    private const string Reserved = "system-reserved-storage-off";
    private const string Components = "tools-component-cleanup";

    private static JsonElement DismBlocks(string id, string state, int code) => Oracle.Run("Invoke-TweakBlocks.ps1",
        "-Src", Repo.Src, "-Ids", id, "-ReservedStorage", state, "-DismCode", code.ToString());

    [Theory]
    [InlineData("Enabled", "Default")]
    [InlineData("Disabled", "Optimized")]
    [InlineData(";", "Unknown")]
    public void Reserved_storage_reads_the_same_state(string state, string want)
    {
        _h.Drivers.ReservedState = state == ";" ? null : state;
        Assert.Equal(want, Result(DismBlocks(Reserved, state, 0), Reserved));
        Assert.Equal(Enum.Parse<TweakState>(want), _h.State(Reserved));
    }

    [Theory]
    [InlineData(0)]
    [InlineData(unchecked((int)0x800F0975))]
    public void Reserved_storage_runs_the_same_dism_and_fails_the_same(int code)
    {
        var ps = DismBlocks(Reserved, "Enabled", code);
        _h.Drivers.ReservedState = "Enabled";
        _h.Drivers.ExeCode = code;
        var o = _h.Run(Reserved, TweakMode.Apply);
        var apply = Lines(ps, Reserved, "Apply");
        Assert.Equal(Of(apply, "dism"), _h.Drivers.Dism);
        Assert.Equal(code == 0 ? (OutcomeKind.Applied, "") : (OutcomeKind.Failed, apply[^1][6..]), (o.Kind, code == 0 ? "" : o.Message));

        _h.Drivers.Dism.Clear();
        _h.Drivers.ReservedState = "Disabled";
        var r = _h.Run(Reserved, TweakMode.Revert);
        var revert = Lines(ps, Reserved, "Revert");
        Assert.Equal(Of(revert, "dism"), _h.Drivers.Dism);
        Assert.Equal(code == 0 ? OutcomeKind.Reverted : OutcomeKind.Failed, r.Kind);
    }

    [Theory]
    [InlineData(0, OutcomeKind.Applied)]
    [InlineData(3010, OutcomeKind.Applied)]
    [InlineData(5, OutcomeKind.Failed)]
    public void The_component_cleanup_runs_the_same_dism(int code, OutcomeKind kind)
    {
        var apply = Lines(DismBlocks(Components, ";", code), Components, "Apply");
        _h.Drivers.ExeCode = code;
        var o = _h.Run(Components, TweakMode.Apply);
        Assert.Equal(Of(apply, "dism"), _h.Drivers.Dism);
        Assert.Equal(kind, o.Kind);
        if (kind == OutcomeKind.Failed) Assert.Equal(apply[^1][6..], o.Message);
    }

    [Theory]
    [InlineData("Deployment Image Servicing and Management tool\r\nVersion: 10.0.26100.1\r\n\r\nImage Version: 10.0.26100.2033\r\n\r\nReserved storage is enabled.\r\nThe operation completed successfully.\r\n", "Enabled")]
    [InlineData("Reserved storage is disabled.\r\n", "Disabled")]
    [InlineData("Error: 87\r\n\r\nThe get-reservedstoragestate option is unknown.\r\n", null)]
    public void Dism_text_says_reserved_storages_state(string output, string? want) => Assert.Equal(want, Core.Apps.DismApi.ReservedStateOf(output));
}
