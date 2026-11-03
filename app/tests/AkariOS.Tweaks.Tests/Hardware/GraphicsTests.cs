using System.Text.Json;
using System.Text.RegularExpressions;
using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Runs;
using AkariOS.Core.Tests;
using AkariOS.Core.Tweaks;
using AkariOS.Tweaks.Hardware.Graphics;

namespace AkariOS.Tweaks.Tests.Hardware;

/// <summary>Hardware › Graphics (g8) on a test key and fakes: per-GPU values, the NVIDIA profile through Profile
/// Inspector, AMD Software. Each Detect, registry write and tool call is compared with the PowerShell blocks run with
/// recorders on the same test key and folders (Oracle/Invoke-TweakBlocks.ps1).</summary>
public sealed class GraphicsTests : IDisposable
{
    private readonly TweakHarness _h = new();

    public void Dispose() => _h.Dispose();

    private static readonly string[] Gpus = ["AMD|0000", "AMD|0001", "NVIDIA|0002", "NVIDIA|0003", "Intel|0004"];
    private static readonly string[] Devices = [@"PCI\VEN_1002&DEV_73BF&SUBSYS_0E3A1002&REV_C1\4&1", @"PCI\VEN_10DE&DEV_2684&SUBSYS_16F110DE&REV_A1\4&2"];

    private static string GpuPath(string key) => $@"{MachineInfo.GpuClass}\{key}";

    public GraphicsTests()
    {
        _h.Pc.Gpus = Gpus.Select(g => g.Split('|')).Select(p => new Gpu(GpuPath(p[1]), $"{p[0]} card", p[0])).ToList();
        _h.Pc.GpuDevices = Devices;
        // a PC's adapter keys always exist (Get-AkariGpus found them there); the MSI keys only once something wrote them
        foreach (var g in _h.Pc.Gpus) _h.Engine.Registry.CreateKey(g.Path);
    }

    private JsonElement Blocks(IEnumerable<string> ids, string? remembered = null)
    {
        var args = new List<string>
        {
            "-Src", Repo.Src, "-Ids", string.Join(",", ids), "-TestRoot", _h.KeyRoot,
            "-Gpus", string.Join(";", _h.Pc.Gpus.Select(g => $"{g.Vendor}|{g.Path}")), "-GpuDevices", string.Join(";", Devices),
            "-ProgramFiles", _h.Folder("Program Files"), "-ProgramFilesX86", _h.Folder("Program Files (x86)"), "-ProgramData", _h.Folder("ProgramData"),
        };
        if (remembered is not null) args.AddRange(["-Remembered", remembered]);
        return Oracle.Run("Invoke-TweakBlocks.ps1", [.. args]);
    }

    private static List<string> Lines(JsonElement e, string id, string block) => BlockLines.Lines(e, id, block);

    private static string Result(JsonElement e, string id) => BlockLines.Result(e, id);

    private void AssertWrites(IReadOnlyList<string> ps) => BlockLines.AssertWrites(_h, ps);

    private void AssertSameDetect(IEnumerable<string> ids)
    {
        var ps = Blocks(ids);
        foreach (var id in ids) Assert.True(Result(ps, id) == _h.State(id).ToString(), $"{id}: PowerShell {Result(ps, id)}, C# {_h.State(id)}");
    }

    [Fact]
    public void Every_graphics_tweak_is_native_now() => Assert.All(
        TweakHarness.All.Where(t => t.Section == "Hardware" && t.Category == "Graphics"),
        t => Assert.Null(Runner.NotNative(_h.Tweak(t.Id))));

    [Fact]
    public void The_download_url_is_the_powershell_apps()
    {
        var text = File.ReadAllText(Path.Combine(Repo.Src, "Core", "AppSetup.ps1"));
        var url = AkariFiles.Url;
        Assert.Equal(Regex.Match(text, @"\$AkariFilesUrl = '([^']+)'").Groups[1].Value, url);
    }

    [Fact]
    public void Open_display_opens_the_settings_page()
    {
        Assert.Equal(OutcomeKind.Applied, _h.Run("graphics-open-display", TweakMode.Apply).Kind);
        Assert.Equal(["ms-settings:display"], _h.Launcher.Opened);
    }

    [Fact]
    public void Per_gpu_tweaks_read_and_write_as_the_powershell_blocks_do()
    {
        string[] ids = ["graphics-amd-ulps-off", "graphics-hdcp-off", "graphics-p0-state", "graphics-intel-settings", "graphics-msi-mode"];
        AssertSameDetect(ids);
        foreach (var id in ids) Assert.Equal(id == "graphics-msi-mode" ? TweakState.Unknown : TweakState.Default, _h.State(id));

        var ps = Blocks(ids);
        foreach (var id in ids)
        {
            Assert.Equal(OutcomeKind.Applied, _h.Run(id, TweakMode.Apply).Kind);
            AssertWrites(Lines(ps, id, "Apply"));
            Assert.Equal(TweakState.Optimized, _h.State(id));
        }
        AssertSameDetect(ids);

        // a mix: some adapters changed, some not
        _h.Set(GpuPath("0001"), "EnableUlps", 1, "DWord");
        _h.Set(GpuPath("0003"), "RMHdcpKeyglobZero", 0, "DWord");
        _h.Set(GpuPath("0002"), "DisableDynamicPstate", 0, "DWord");
        _h.Engine.Registry.RemoveValue($@"{GpuPath("0004")}\3DKeys", "Global_LowLatency");
        _h.Engine.Registry.RemoveValue(MsiMode.Key(Devices[1]), "MSISupported");
        AssertSameDetect(ids);
        foreach (var id in ids) Assert.Equal(TweakState.Custom, _h.State(id));

        ps = Blocks(ids);
        foreach (var id in ids)
        {
            Assert.Equal(OutcomeKind.Reverted, _h.Run(id, TweakMode.Revert).Kind);
            AssertWrites(Lines(ps, id, "Revert"));
        }
        Assert.False(_h.Engine.Registry.KeyExists($@"{GpuPath("0004")}\3DKeys"));
        AssertSameDetect(ids);
    }

    [Fact]
    public void Amd_settings_open_amd_software_then_write_as_the_powershell_blocks_do()
    {
        const string id = "graphics-amd-settings";
        var rs = Path.Combine(_h.Folder(@"Program Files\AMD\CNext\CNext"), "RadeonSoftware.exe");
        File.WriteAllText(rs, "");
        // the driver made UMD and power_v1 for the first adapter only; old notifications to clear
        _h.Engine.Registry.CreateKey($@"{GpuPath("0000")}\UMD");
        _h.Engine.Registry.CreateKey($@"{GpuPath("0000")}\power_v1");
        _h.Set(@"HKCU:\Software\AMD\CN\Notification", "Old", 1, "DWord");

        var ps = Blocks([id]);
        Assert.Equal("Default", Result(ps, id));
        Assert.Equal(TweakState.Default, _h.State(id));
        var apply = Lines(ps, id, "Apply");
        Assert.Equal([$"open {rs}", "sleep 30", "stop RadeonSoftware", "sleep 2"], apply.Take(4));
        Assert.Equal(OutcomeKind.Applied, _h.Run(id, TweakMode.Apply).Kind);
        Assert.Equal(["RadeonSoftware.exe "], _h.Exe.Runs);
        Assert.Equal(["RadeonSoftware"], _h.Processes.Stopped);
        AssertWrites(apply);
        Assert.Empty(_h.Engine.Registry.ValueNames(@"HKCU:\Software\AMD\CN\Notification"));
        Assert.False(_h.Engine.Registry.KeyExists($@"{GpuPath("0001")}\UMD"));
        AssertSameDetect([id]);
        Assert.Equal(TweakState.Optimized, _h.State(id));

        ps = Blocks([id]);
        Assert.Equal(OutcomeKind.Reverted, _h.Run(id, TweakMode.Revert).Kind);
        AssertWrites(Lines(ps, id, "Revert"));
        AssertSameDetect([id]);
        Assert.Equal(TweakState.Default, _h.State(id));
    }

    [Fact]
    public void Amd_settings_skip_amd_software_when_it_is_not_installed()
    {
        const string id = "graphics-amd-settings";
        Assert.DoesNotContain(Lines(Blocks([id]), id, "Apply"), l => l.StartsWith("open ", StringComparison.Ordinal));
        Assert.Equal(OutcomeKind.Applied, _h.Run(id, TweakMode.Apply).Kind);
        Assert.Empty(_h.Exe.Runs);
        Assert.Empty(_h.Processes.Stopped);
    }

    // a file of the driver's profile store with the Mark of the Web
    private string BlockedDrsFile()
    {
        var f = Path.Combine(_h.Folder(@"ProgramData\NVIDIA Corporation\Drs\sub"), "nvdrsdb0.bin");
        File.WriteAllText(f, "x");
        File.WriteAllText($"{f}:Zone.Identifier", "[ZoneTransfer]\r\nZoneId=3");
        Assert.True(File.Exists($"{f}:Zone.Identifier"));
        return f;
    }

    private static readonly string TweakFiles = Path.Combine(Repo.Src, "Tweaks", "Hardware", "Graphics", "Files");

    // the PowerShell block's tool lines, as the C# fakes record them: the .nip from the Files folder it was written to
    private List<string> ToolLines(IEnumerable<string> ps) => ps.Where(l => l.Split(' ')[0] is "download" or "shortcut" or "run" or "unblock")
        .Select(l => l.Replace(TweakFiles, _h.Folder("Files"), StringComparison.OrdinalIgnoreCase)).ToList();

    private List<string> CsToolLines(string drsFile, bool unblocked)
    {
        var lines = new List<string>();
        if (unblocked) lines.Add($"unblock {Path.GetRelativePath(_h.Folder("ProgramData"), drsFile)}");
        lines.AddRange(_h.Downloads.Saved.Select(s => $"download {s}"));
        lines.AddRange(_h.Shortcuts.Made.Select(m => $"shortcut {Path.GetFileNameWithoutExtension(m.Key)}|{m.Value}"));
        var exe = ProfileInspector.Exe(_h.Engine.Context);
        lines.AddRange(_h.Exe.Runs.Select(r => $"run {exe}|{r[(Path.GetFileName(exe).Length + 1)..]}"));
        return lines;
    }

    [Fact]
    public void Nvidia_settings_write_and_import_the_profile_as_the_powershell_blocks_do()
    {
        const string id = "graphics-nvidia-settings";
        var drs = BlockedDrsFile();
        var ps = Blocks([id]);
        Assert.Equal(TweakState.Default, _h.State(id));
        AssertSameDetect([id]);

        Assert.Equal(OutcomeKind.Applied, _h.Run(id, TweakMode.Apply).Kind);
        var apply = Lines(ps, id, "Apply");
        AssertWrites(apply);
        Assert.False(File.Exists($"{drs}:Zone.Identifier"));
        Assert.Equal(ToolLines(apply), CsToolLines(drs, unblocked: true));
        var exe = ProfileInspector.Exe(_h.Engine.Context);
        Assert.Equal(Path.GetDirectoryName(exe), _h.Shortcuts.WorkingFolders.Single().Value);
        Assert.Equal(File.ReadAllBytes(Path.Combine(TweakFiles, "nvidia-base-profile.nip")), File.ReadAllBytes(Path.Combine(_h.Folder("Files"), "nvidia-base-profile.nip")));
        AssertSameDetect([id]);
        Assert.Equal(TweakState.Optimized, _h.State(id));

        // Profile Inspector is there now: the PowerShell block doesn't download it again either
        File.WriteAllText($"{drs}:Zone.Identifier", "ZoneId=3");
        _h.Downloads.Saved.Clear();
        _h.Shortcuts.Made.Clear();
        _h.Exe.Runs.Clear();
        ps = Blocks([id]);
        Assert.Equal(OutcomeKind.Reverted, _h.Run(id, TweakMode.Revert).Kind);
        var revert = Lines(ps, id, "Revert");
        AssertWrites(revert);
        Assert.Equal(ToolLines(revert), CsToolLines(drs, unblocked: true));
        Assert.Empty(_h.Downloads.Saved);
        AssertSameDetect([id]);
    }

    [Fact]
    public void Rebar_reads_and_writes_what_akari_last_did()
    {
        const string id = "graphics-nvidia-rebar-force";
        var drs = BlockedDrsFile();
        var ps = Blocks([id]);
        Assert.Equal(["remembered graphics-nvidia-rebar-force", "result Default"], Lines(ps, id, "Detect"));
        Assert.Equal(TweakState.Default, _h.State(id));
        Assert.Equal("Optimized", Result(Blocks([id], remembered: "true"), id));

        Assert.Equal(OutcomeKind.Applied, _h.Run(id, TweakMode.Apply).Kind);
        var apply = Lines(ps, id, "Apply");
        Assert.Equal(ToolLines(apply), CsToolLines(drs, unblocked: true));
        Assert.Contains("-mergeImport", _h.Exe.Runs.Single());
        Assert.Equal("remember graphics-nvidia-rebar-force True", apply[^1]);
        Assert.True(_h.Remembered.Get(id));
        Assert.Equal(TweakState.Optimized, _h.State(id));

        // Revert: the empty profile, or FR33THY's while graphics-nvidia-settings' registry part is there
        foreach (var fr33thy in new[] { false, true })
        {
            if (fr33thy)
            {
                _h.Set(NvidiaSettings.NvTweak, "NvCplPhysxAuto", 0, "DWord");
                _h.Set(NvidiaSettings.NvTweak, "NvDevToolsVisible", 1, "DWord");
                _h.Remembered.Set(id, true);
            }
            _h.Downloads.Saved.Clear();
            _h.Shortcuts.Made.Clear();
            _h.Exe.Runs.Clear();
            var revert = Lines(Blocks([id]), id, "Revert");
            Assert.Equal(OutcomeKind.Reverted, _h.Run(id, TweakMode.Revert).Kind);
            Assert.Equal(ToolLines(revert), CsToolLines(drs, unblocked: true));
            Assert.Contains(fr33thy ? "nvidia-base-profile.nip" : "nvidia-default-profile.nip", _h.Exe.Runs.Single());
            Assert.Equal("remember graphics-nvidia-rebar-force False", revert[^1]);
            Assert.False(_h.Remembered.Get(id));
        }
    }

    [Fact]
    public void Gpu_tweaks_with_no_adapter_of_their_vendor_read_unknown()
    {
        _h.Pc.Gpus = [];
        _h.Pc.GpuDevices = [];
        string[] ids = ["graphics-amd-ulps-off", "graphics-hdcp-off", "graphics-p0-state", "graphics-intel-settings", "graphics-msi-mode"];
        foreach (var id in ids) Assert.Equal(TweakState.Unknown, _h.State(id));
    }

    [Fact]
    public void Legacy_sharpen_uses_the_parameters_key_only_when_the_driver_has_it()
    {
        const string id = "nvidia-legacy-sharpen";
        foreach (var parameters in new[] { false, true })
        {
            if (parameters) _h.Engine.Registry.CreateKey(NvidiaLegacySharpen.ParametersFts);
            var key = parameters ? NvidiaLegacySharpen.ParametersFts : NvidiaLegacySharpen.Fts;
            var ps = Blocks([id]);
            Assert.Equal([$"row {key}|EnableGR535|0|"], Lines(ps, id, "Detect").Where(l => l.StartsWith("row ", StringComparison.Ordinal)));
            Assert.Equal(TweakState.Default, _h.State(id));
            Assert.Equal(OutcomeKind.Applied, _h.Run(id, TweakMode.Apply).Kind);
            AssertWrites(Lines(ps, id, "Apply"));
            Assert.Equal(TweakState.Optimized, _h.State(id));
            Assert.Equal(OutcomeKind.Reverted, _h.Run(id, TweakMode.Revert).Kind);
            AssertWrites(Lines(ps, id, "Revert"));
        }
    }
}
