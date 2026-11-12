using System.Text.Json;
using AkariOS.Core.Machine;
using AkariOS.Core.Runs;
using AkariOS.Core.Tests;
using AkariOS.Core.Tweaks;
using static AkariOS.Tweaks.Tests.BlockLines;

namespace AkariOS.Tweaks.Tests.Apps;

/// <summary>
/// The legacy app removals (N5b) against their PowerShell blocks (Oracle/Invoke-TweakBlocks.ps1): the same Detect, the
/// same programs run, services, processes and tasks touched, registry writes, and the same files left in the
/// program folders. The PowerShell side works on its own copy of the folders; the registry is the shared test key
/// (its blocks only record their writes).
/// </summary>
public sealed class RemoveTests : IDisposable
{
    private readonly TweakHarness _h = new();
    private readonly AppRoots _cs;
    private readonly AppRoots _ps;

    public RemoveTests()
    {
        var s = _h.Engine.Services;
        _cs = new AppRoots(s.Windows, s.ProgramFiles, s.ProgramFilesX86, s.ProgramData, s.Public, _h.Folder("User"), s.LocalAppData);
        _ps = new AppRoots(_h.Folder("ps-Windows"), _h.Folder("ps-pf"), _h.Folder("ps-pf86"), _h.Folder("ps-data"), _h.Folder("ps-public"), _h.Folder("ps-user"), _h.Folder("ps-local"));
        const string folders = @"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders";
        _h.Set(folders, "AppData", _cs.User, "String");
        _h.Set(folders, "Local AppData", _cs.User, "String");
    }

    public void Dispose() => _h.Dispose();

    private void Files(params string[] files)
    {
        foreach (var f in files) { _cs.Add(f); _ps.Add(f); }
    }

    private void Services(params string[] names)
    {
        foreach (var n in names) _h.Services.Installed[n] = "Automatic";
    }

    private void Processes(params string[] names) => _h.Processes.Names.AddRange(names);

    private void Tasks(params (string Folder, string Name)[] tasks)
    {
        foreach (var t in tasks) _h.Tasks.All[new ScheduledTask(t.Folder, t.Name)] = true;
    }

    /// <summary>The PowerShell blocks on the same machine (the services, processes and tasks given to the fakes).</summary>
    private JsonElement Blocks(string ids) => Oracle.Run("Invoke-TweakBlocks.ps1",
    [
        "-Src", Repo.Src, "-Ids", ids, "-TestRoot", _h.KeyRoot, "-SystemRoot", _ps.Windows, "-ProgramFiles", _ps.ProgramFiles,
        "-ProgramFilesX86", _ps.X86, "-ProgramData", _ps.ProgramData, "-Public", _ps.Public, "-UserFolder", _ps.User,
        "-Services", Joined(_h.Services.Installed.Keys), "-Processes", Joined(_h.Processes.Names),
        "-Tasks", Joined(_h.Tasks.All.Keys.Select(t => $"{(t.Folder == "\\" ? "\\" : t.Folder + "\\")}|{t.Name}")),
    ]);

    // Oracle.Run never gets an empty argument
    private static string Joined(IEnumerable<string> items) => items.Any() ? string.Join(";", items) : ";";

    private static List<string> PsRuns(IEnumerable<string> lines) => lines.Select(l =>
        l.StartsWith("run ", StringComparison.Ordinal) ? $"{Path.GetFileName(l[4..].Split('|')[0])} {l[4..].Split('|', 2)[1]}"
        : l.StartsWith("takeown ", StringComparison.Ordinal) || l.StartsWith("icacls ", StringComparison.Ordinal) ? $"{l.Split(' ')[0]}.exe {l.Split(' ', 2)[1]}"
        : null).OfType<string>().ToList();

    private List<string> CsRuns() => _h.Exe.Runs.Select(r =>
    {
        foreach (var (v, p) in _cs.All()) r = r.Replace(p, v, StringComparison.OrdinalIgnoreCase);
        // the quotes around a test folder's path (PowerShell passes it as one argument)
        return System.Text.RegularExpressions.Regex.Replace(r, "\"(%[^\"]*)\"", "$1");
    }).ToList();

    private static List<string> PsOf(IEnumerable<string> lines, string kind) =>
        lines.Where(l => l.StartsWith(kind + " ", StringComparison.Ordinal)).Select(l => l[(kind.Length + 1)..]).ToList();

    /// <summary>Applies it in C# and compares with the PowerShell Apply's lines: programs, services, processes, tasks,
    /// registry writes, the folders left.</summary>
    private void AssertSameApply(JsonElement ps, string id)
    {
        Assert.Equal("False", Result(ps, id));
        Assert.Equal(TweakState.Default, _h.Engine.Codes[id].Detect(_h.Tweak(id), _h.Engine.Context));
        var lines = Lines(ps, id, "Apply");
        Assert.Equal(OutcomeKind.Applied, _h.Run(id, TweakMode.Apply).Kind);
        Assert.Equal(PsRuns(lines), CsRuns());
        Assert.Equal(PsOf(lines, "stopservice").Select(s => $"stop {s}").Concat(PsOf(lines, "delservice").Select(s => $"delete {s}")).Order(),
            _h.Services.Calls.Order());
        Assert.Equal(PsOf(lines, "stop"), _h.Processes.Stopped);
        Assert.Equal(PsOf(lines, "unregister").Select(t => t.Split('|')[1]).Order(), _h.Tasks.Unregistered.Select(t => t.Name).Order());
        if (lines.Any(l => l.Split(' ')[0] is "set" or "delkey")) AssertWrites(_h, lines);
        Assert.Equal(_ps.Tree(), _cs.Tree());
    }

    [Fact]
    public void Every_legacy_removal_is_native_now() => Assert.All(
        TweakHarness.All.Where(t => t.Section == "Apps" && t.Category == "Remove"),
        t => Assert.Null(Runner.NotNative(_h.Tweak(t.Id))));

    private const string Uninstall = @"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall";
    private const string Uninstall32 = @"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall";

    [Fact]
    public void The_msi_removals_uninstall_each_matching_product()
    {
        _h.Set($@"{Uninstall}\{{11111111-0000-0000-0000-000000000001}}", "DisplayName", "Microsoft GameInput", "String");
        _h.Set($@"{Uninstall}\{{11111111-0000-0000-0000-000000000002}}", "DisplayName", "Update for x64-based Windows Systems (KB5001716)", "String");
        _h.Set($@"{Uninstall32}\{{11111111-0000-0000-0000-000000000003}}", "DisplayName", "Microsoft Update Health Tools", "String");
        _h.Set($@"{Uninstall32}\Other", "DisplayName", "Something else", "String");
        _h.Set(@"HKLM:\SYSTEM\ControlSet001\Services\uhssvc", "Start", 2, "DWord");
        Tasks(("\\", "PLUGScheduler"), (@"\Microsoft", "Other"));
        string[] ids = ["remove-gameinput", "remove-update-for-x64", "remove-update-health-tools"];
        var ps = Blocks(string.Join(",", ids));
        foreach (var id in ids)
        {
            _h.Exe.Runs.Clear();
            AssertSameApply(ps, id);
        }
        Assert.Equal(["Uninstalling: Microsoft GameInput", "Uninstalling: Update for x64-based Windows Systems (KB5001716)", "Uninstalling: Microsoft Update Health Tools"],
            _h.Log.Lines.Where(l => l.StartsWith("Uninstalling", StringComparison.Ordinal)));

        // gone: done on both sides
        foreach (var k in new[] { $@"{Uninstall}\{{11111111-0000-0000-0000-000000000001}}", $@"{Uninstall}\{{11111111-0000-0000-0000-000000000002}}", $@"{Uninstall32}\{{11111111-0000-0000-0000-000000000003}}" })
            _h.Engine.Registry.DeleteKey(k);
        ps = Blocks(string.Join(",", ids));
        foreach (var id in ids) Assert.Equal(("True", OutcomeKind.Already), (Result(ps, id), _h.Run(id, TweakMode.Apply).Kind));
    }

    [Fact]
    public void Remote_desktop_and_the_old_snipping_tool_uninstall_themselves()
    {
        Files(@"%SystemRoot%\System32\mstsc.exe", @"%SystemRoot%\System32\SnippingTool.exe");
        Processes("mstsc", "SnippingTool");
        var ps = Blocks("remove-remote-desktop-connection,remove-snipping-tool-legacy");
        AssertSameApply(ps, "remove-remote-desktop-connection");
        _h.Exe.Runs.Clear();
        _h.Processes.Stopped.Clear();
        AssertSameApply(ps, "remove-snipping-tool-legacy");
        Assert.Equal(["SnippingTool"], _h.Processes.Stopped);

        File.Delete(Path.Combine(_cs.Windows, @"System32\mstsc.exe"));
        Assert.Equal(OutcomeKind.Already, _h.Run("remove-remote-desktop-connection", TweakMode.Apply).Kind);
    }

    [Fact]
    public void Brlapi_goes_with_its_folder()
    {
        Files(@"%SystemRoot%\brltty\brltty.exe", @"%SystemRoot%\brltty\lib\x.dll");
        Services("brlapi");
        AssertSameApply(Blocks("remove-brlapi"), "remove-brlapi");
        Assert.Equal(OutcomeKind.Already, _h.Run("remove-brlapi", TweakMode.Apply).Kind);
    }

    [Fact]
    public void OneDrive_runs_every_setup_and_drops_its_tasks()
    {
        Files(@"%SystemRoot%\System32\OneDriveSetup.exe", @"%ProgramFiles%\Microsoft OneDrive\OneDrive.exe", @"%ProgramFiles%\Microsoft OneDrive\25.1.0\OneDriveSetup.exe",
            @"%User%\Microsoft\OneDrive\OneDrive.exe", @"%User%\Microsoft\OneDrive\24.9\OneDriveSetup.exe");
        Processes("OneDrive");
        Tasks(("\\", "OneDrive Standalone Update Task-S-1-5-21-1"), ("\\", "OneDrive Reporting Task-S-1-5-21-1"), (@"\Microsoft", "Other"));
        AssertSameApply(Blocks("remove-onedrive"), "remove-onedrive");
        Assert.Equal(["OneDriveSetup.exe -uninstall", "OneDriveSetup.exe /uninstall /allusers", "OneDriveSetup.exe /uninstall /allusers"], _h.Exe.Runs);
    }

    // Edge, WebView2 and Edge Update as they are on Windows 11, plus Windows 10's built-in Edge package
    private void Edge(bool edge = true, bool webView = true)
    {
        Files(@"%ProgramFiles(x86)%\Microsoft\EdgeUpdate\1.3.195.61\MicrosoftEdgeUpdate.exe", @"%ProgramFiles(x86)%\Microsoft\EdgeUpdate\Download\x.bin",
            @"%PUBLIC%\Desktop\Microsoft Edge.lnk", @"%ProgramData%\Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk",
            @"%User%\Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk", @"%SystemRoot%\System32\cmd.exe");
        if (edge) Files(@"%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe");
        if (webView) Files(@"%ProgramFiles(x86)%\Microsoft\EdgeWebView\Application\msedgewebview2.exe");
        _h.Set(@"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge", "UninstallString", "\"C:\\Edge\\setup.exe\" --uninstall --msedge", "String");
        _h.Set(@"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView", "UninstallString", "\"C:\\Edge\\setup.exe\" --uninstall --msedgewebview", "String");
        const string cbs = @"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages\Microsoft-Windows-Internet-Browser-Package~31bf3856ad364e35~amd64~~10.0.19041.1";
        _h.Set(cbs, "Visibility", 2, "DWord");
        _h.Set($@"{cbs}\Owners", "x", 1, "DWord");
        Services("MicrosoftEdgeElevationService", "edgeupdate", "edgeupdatem", "Spooler");
        Processes("msedge", "msedgewebview2", "MicrosoftEdgeUpdate", "explorer");
        Tasks(("\\", "MicrosoftEdgeUpdateTaskMachineCore"), ("\\", "MicrosoftEdgeUpdateTaskMachineUA"), (@"\Microsoft", "Other"));
    }

    [Fact]
    public void Edge_goes_and_edge_update_stays_for_webview2()
    {
        Edge();
        AssertSameApply(Blocks("remove-edge"), "remove-edge");
        Assert.True(File.Exists(Path.Combine(_cs.X86, @"Microsoft\EdgeUpdate\1.3.195.61\MicrosoftEdgeUpdate.exe")));
        Assert.Contains(@"cmd.exe /c ""C:\Edge\setup.exe"" --uninstall --msedge --force-uninstall", _h.Exe.Runs);
        Assert.Equal(1u, _h.Get(@"HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate", "DoNotUpdateToEdgeWithChromium"));
        Assert.Equal(OutcomeKind.Already, _h.Run("remove-edge", TweakMode.Apply).Kind);
    }

    [Fact]
    public void Edge_after_webview2_takes_edge_update_too()
    {
        Edge(webView: false);
        AssertSameApply(Blocks("remove-edge"), "remove-edge");
        Assert.False(Directory.Exists(Path.Combine(_cs.X86, @"Microsoft\EdgeUpdate")));
        Assert.Equal(["MicrosoftEdgeElevationService", "edgeupdate", "edgeupdatem"], _h.Services.Calls.Where(c => c.StartsWith("delete")).Select(c => c[7..]));
    }

    [Fact]
    public void Webview2_after_edge_takes_edge_update_too()
    {
        Edge(edge: false);
        AssertSameApply(Blocks("remove-webview2"), "remove-webview2");
        Assert.False(Directory.Exists(Path.Combine(_cs.X86, @"Microsoft\EdgeUpdate")));
        Assert.Equal(0u, _h.Get(@"HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate", "Install{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"));
    }

    [Fact]
    public void Webview2_alone_leaves_edge_update_for_edge()
    {
        Edge();
        AssertSameApply(Blocks("remove-webview2"), "remove-webview2");
        Assert.True(Directory.Exists(Path.Combine(_cs.X86, @"Microsoft\EdgeUpdate")));
    }
}
