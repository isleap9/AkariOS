using System.Text.Json;
using AkariOS.Core.Machine;
using AkariOS.Core.Runs;
using AkariOS.Core.Tests;
using AkariOS.Core.Tweaks;
using static AkariOS.Tweaks.Tests.BlockLines;

namespace AkariOS.Tweaks.Tests.Advanced;

/// <summary>Advanced/Features (winutil W2) against their PowerShell blocks (Oracle/Invoke-TweakBlocks.ps1): the same
/// States, the same features and capabilities turned on or off (with the same Windows source), the same services, task,
/// registry values and console lines, the same failures.</summary>
public sealed class FeaturesTests : IDisposable
{
    private readonly TweakHarness _h = new();
    private const string ServicesRoot = @"HKLM:\SYSTEM\CurrentControlSet\Services";
    private const string Ssh = "OpenSSH.Server~~~~0.0.1.0";

    public void Dispose() => _h.Dispose();

    private string ProgramData => _h.Engine.Services.ProgramData;

    private JsonElement Blocks(string id, params string[] more) => Oracle.Run("Invoke-TweakBlocks.ps1",
        ["-Src", Repo.Src, "-Ids", id, "-TestRoot", _h.KeyRoot, "-ProgramData", ProgramData, "-Logs", .. more]);

    /// <summary>The PC's features ('name=state;…', as the oracle takes them).</summary>
    private void Features(string states)
    {
        foreach (var p in states.Split(';', StringSplitOptions.RemoveEmptyEntries))
        {
            var (n, s) = (p.Split('=')[0], p.Split('=')[1]);
            _h.Drivers.FeatureStates[n] = s;
        }
    }

    /// <summary>A service on the PC: its start type for Get-AkariServices / One, and its key for Set-AkariServiceStart.</summary>
    private void Service(string name, string start)
    {
        _h.Services.Installed[name] = start;
        _h.Set($@"{ServicesRoot}\{name}", "Start", ServiceLists.StartValue(start).Start, "DWord");
    }

    private static string Starts(params (string Name, string Start)[] s) => s.Length == 0 ? ";" : string.Join(";", s.Select(x => $"{x.Name}={x.Start}"));

    private string Normal(string line) => line.Replace(ProgramData, "%ProgramData%", StringComparison.OrdinalIgnoreCase);

    /// <summary>The PowerShell console lines, in order, one after the other in the C# log.</summary>
    private void AssertLogged(IReadOnlyList<string> ps)
    {
        var want = ps.Where(l => l.StartsWith("log ", StringComparison.Ordinal)).Select(l => l[4..]).ToList();
        var cs = _h.Log.Lines.Select(Normal).ToList();
        if (want.Count == 0) return;
        var at = cs.IndexOf(want[0]);
        Assert.True(at >= 0, $"not logged: {want[0]}");
        Assert.Equal(want, cs.Skip(at).Take(want.Count).ToList());
    }

    /// <summary>What the block did that C# records (each fake keeps its own order, the log checks the whole order):
    /// features, capabilities, service starts and stops, the task and the keys file, sorted.</summary>
    private static List<string> PsDid(IEnumerable<string> lines) =>
        Of(lines, "feature", "capability", "servicecontrol", "dailytask", "unregistertask", "adminacl").Order(StringComparer.Ordinal).ToList();

    private List<string> CsDid() => _h.Drivers.Dism
        .Concat(_h.Services.Calls.Where(c => c.StartsWith("control ", StringComparison.Ordinal)).Select(c => $"servicecontrol {c[8..]}"))
        .Concat(_h.Tasks.Daily.Select(d => $"dailytask {d}"))
        .Concat(_h.Tasks.Unregistered.Select(t => $"unregistertask {t.Folder}\\|{t.Name}"))
        .Concat(_h.Acl.Made.Select(p => $"adminacl {Normal(p)}"))
        .Order(StringComparer.Ordinal).ToList();

    /// <summary>The services' start types the block left (its last "servicestart" for each) are in the test key.</summary>
    private void AssertStarts(IEnumerable<string> ps)
    {
        var last = new Dictionary<string, string>();
        foreach (var p in Of(ps, "servicestart").Select(l => l.Split(' '))) last[p[1]] = p[2];
        foreach (var (name, start) in last)
            Assert.True(Equals((uint)ServiceLists.StartValue(start).Start, _h.Get($@"{ServicesRoot}\{name}", "Start")), $"{name}'s start type");
    }

    private void AssertSame(IReadOnlyList<string> ps, Outcome o, OutcomeKind ok)
    {
        if (ps.Count > 0 && ps[^1].StartsWith("throw ", StringComparison.Ordinal))
            Assert.Equal((OutcomeKind.Failed, ps[^1][6..]), (o.Kind, o.Message));
        else Assert.Equal(ok, o.Kind);
        Assert.Equal(PsDid(ps), CsDid());
        AssertStarts(ps);
        AssertLogged(ps);
    }

    [Theory]
    [InlineData("features-dotnet35", "NetFx3=Enabled;NetFx4-AdvSrvs=EnablePending", "Optimized")]
    [InlineData("features-dotnet35", "NetFx3=DisabledWithPayloadRemoved;NetFx4-AdvSrvs=Enabled", "Default")]
    [InlineData("features-dotnet35", "NetFx3=Enabled;NetFx4-AdvSrvs=Disabled", "Custom")]
    [InlineData("features-legacy-media", "WindowsMediaPlayer=Enabled;MediaPlayback=Enabled;DirectPlay=DisablePending", "Default")]
    [InlineData("features-legacy-media", "WindowsMediaPlayer=Disabled;MediaPlayback=Enabled;DirectPlay=Disabled;LegacyComponents=Disabled", "Custom")]
    [InlineData("features-wsl", "VirtualMachinePlatform=Enabled;Microsoft-Windows-Subsystem-Linux=EnablePending", "Optimized")]
    [InlineData("features-nfs", ";", "Unknown")]
    [InlineData("features-hyperv", "Microsoft-Hyper-V-All=Disabled", "Default")]
    [InlineData("features-sandbox", "Containers-DisposableClientVM=Enabled", "Optimized")]
    public void A_feature_Toggle_reads_its_State_as_PowerShell_does(string id, string states, string state)
    {
        Features(states);
        Assert.Equal(state, Result(Blocks(id, "-FeatureStates", states), id));
        Assert.Equal(state, _h.State(id).ToString());
    }

    [Theory]
    // .NET 3.5 with Windows Update off: turned on for the install, then off again
    [InlineData("features-dotnet35", "Apply", "NetFx3=DisabledWithPayloadRemoved;NetFx4-AdvSrvs=Enabled", "wuauserv=Disabled", false, ";")]
    // a Windows setup plugged in: its files from there, Windows Update left alone
    [InlineData("features-dotnet35", "Apply", "NetFx3=Disabled;NetFx4-AdvSrvs=Disabled", "wuauserv=Disabled", true, ";")]
    // DISM can't get the files: the hint, Windows Update off again
    [InlineData("features-dotnet35", "Apply", "NetFx3=Disabled;NetFx4-AdvSrvs=Enabled", "wuauserv=Disabled", false, "NetFx3")]
    [InlineData("features-dotnet35", "Apply", "NetFx3=Disabled;NetFx4-AdvSrvs=Enabled", "wuauserv=Manual", false, "NetFx3")]
    [InlineData("features-dotnet35", "Revert", "NetFx3=Enabled;NetFx4-AdvSrvs=Disabled", ";", false, ";")]
    // a feature this Windows lacks is skipped; Revert puts Windows Media Player back on, DirectPlay off
    [InlineData("features-legacy-media", "Apply", "WindowsMediaPlayer=Disabled;MediaPlayback=Enabled;DirectPlay=Disabled", ";", false, ";")]
    [InlineData("features-legacy-media", "Revert", "WindowsMediaPlayer=Disabled;MediaPlayback=Enabled;DirectPlay=Enabled;LegacyComponents=EnablePending", ";", false, ";")]
    [InlineData("features-wsl", "Apply", "VirtualMachinePlatform=Disabled;Microsoft-Windows-Subsystem-Linux=Disabled", ";", false, ";")]
    // none of its features here: a failure
    [InlineData("features-nfs", "Apply", ";", ";", false, ";")]
    [InlineData("features-nfs", "Revert", ";", ";", false, ";")]
    public void A_feature_Toggle_turns_the_same_features_on_and_off(string id, string mode, string states, string services, bool source, string fail)
    {
        Features(states);
        foreach (var s in services.Split(';', StringSplitOptions.RemoveEmptyEntries)) Service(s.Split('=')[0], s.Split('=')[1]);
        var sxs = Path.Combine(_h.Folder("ISO"), "sources", "sxs");
        if (source) Directory.CreateDirectory(sxs);
        _h.DriveRoots.Add(_h.Folder("USB"));
        _h.DriveRoots.Add(Path.GetDirectoryName(Path.GetDirectoryName(sxs))!);
        foreach (var f in fail.Split(';', StringSplitOptions.RemoveEmptyEntries)) _h.Drivers.Fail.Add(f);

        var ps = Lines(Blocks(id, "-FeatureStates", states, "-ServiceStarts", services, "-WindowsSource", source ? sxs : ";", "-FeaturesFail", fail), id, mode);
        var o = _h.Run(id, Enum.Parse<TweakMode>(mode));
        AssertSame(ps, o, mode == "Apply" ? OutcomeKind.Applied : OutcomeKind.Reverted);
        if (o.Kind != OutcomeKind.Failed) Assert.True(o.Reboot);
    }

    [Theory]
    [InlineData("bootmenupolicy          Legacy", "Optimized")]
    [InlineData("bootmenupolicy          Standard", "Default")]
    [InlineData(";", "Default")]
    public void F8_recovery_reads_the_boot_menu_policy(string bcd, string state)
    {
        _h.Bcd.Lines = bcd == ";" ? [] : [bcd];
        Assert.Equal(state, Result(Blocks("features-f8-recovery", "-BcdLines", bcd), "features-f8-recovery"));
        Assert.Equal(state, _h.State("features-f8-recovery").ToString());
    }

    [Fact]
    public void F8_recovery_sets_the_boot_menu_policy()
    {
        var ps = Blocks("features-f8-recovery");
        Assert.Equal(OutcomeKind.Applied, _h.Run("features-f8-recovery", TweakMode.Apply).Kind);
        Assert.Equal(Of(Lines(ps, "features-f8-recovery", "Apply"), "bcdedit"), Of(_h.Bcd.Calls, "bcdedit"));

        _h.Bcd.Calls.Clear();
        _h.Bcd.Lines = ["bootmenupolicy          Legacy"];
        var o = _h.Run("features-f8-recovery", TweakMode.Revert);
        Assert.Equal((OutcomeKind.Reverted, true), (o.Kind, o.Reboot));
        Assert.Equal(Of(Lines(ps, "features-f8-recovery", "Revert"), "bcdedit"), Of(_h.Bcd.Calls, "bcdedit"));

        _h.Bcd.ExitCode = 1;
        Assert.Equal("bcdedit could not change the boot menu", _h.Run("features-f8-recovery", TweakMode.Revert).Message);
    }

    private const string Config = @"HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Configuration Manager";

    [Theory]
    [InlineData(true, true, "Optimized")]
    [InlineData(false, false, "Default")]
    [InlineData(true, false, "Custom")]
    [InlineData(false, true, "Custom")]
    public void The_registry_backup_reads_its_values_and_task(bool values, bool task, string state)
    {
        if (values) { _h.Set(Config, "EnablePeriodicBackup", 1u, "DWord"); _h.Set(Config, "BackupCount", 2u, "DWord"); }
        if (task) _h.Tasks.All[new ScheduledTask(@"\AkariOS", "RegistryBackup")] = true;
        Assert.Equal(state, Result(Blocks("features-registry-backup", "-Tasks", task ? @"\AkariOS\|RegistryBackup" : ";"), "features-registry-backup"));
        Assert.Equal(state, _h.State("features-registry-backup").ToString());
    }

    [Fact]
    public void The_registry_backup_writes_its_values_and_a_daily_task_and_removes_them()
    {
        var ps = Blocks("features-registry-backup");
        var apply = Lines(ps, "features-registry-backup", "Apply");
        AssertSame(apply, _h.Run("features-registry-backup", TweakMode.Apply), OutcomeKind.Applied);
        AssertWrites(_h, apply);
        Assert.Equal(TweakState.Optimized, _h.State("features-registry-backup"));

        _h.Tasks.Daily.Clear();
        var revert = Lines(ps, "features-registry-backup", "Revert");
        AssertSame(revert, _h.Run("features-registry-backup", TweakMode.Revert), OutcomeKind.Reverted);
        AssertWrites(_h, revert);
        Assert.Equal(TweakState.Default, _h.State("features-registry-backup"));
    }

    [Theory]
    [InlineData("Installed", "Optimized")]
    [InlineData("NotPresent", "Default")]
    [InlineData(";", "Unknown")]
    public void OpenSSH_Server_reads_its_capability(string cap, string state)
    {
        if (cap != ";") _h.Drivers.CapabilityStates[Ssh] = cap;
        Assert.Equal(state, Result(Blocks("features-openssh-server", "-CapabilityStates", cap == ";" ? ";" : $"{Ssh}={cap}"), "features-openssh-server"));
        Assert.Equal(state, _h.State("features-openssh-server").ToString());
    }

    [Theory]
    // added through Windows Update (off: turned on for it), both services started with Windows, the keys file
    [InlineData("Apply", "NotPresent", "wuauserv=Disabled;sshd=Manual;ssh-agent=Disabled", ";")]
    // no ssh-agent (OpenSSH Client removed): skipped
    [InlineData("Apply", "NotPresent", "sshd=Manual", ";")]
    [InlineData("Apply", "NotPresent", "wuauserv=Manual", Ssh)]
    [InlineData("Revert", "Installed", "sshd=Automatic;ssh-agent=Automatic", ";")]
    [InlineData("Revert", "Installed", "sshd=Automatic", ";")]
    public void OpenSSH_Server_adds_the_capability_starts_its_services_and_guards_the_keys_file(string mode, string cap, string services, string fail)
    {
        _h.Drivers.CapabilityStates[Ssh] = cap;
        foreach (var s in services.Split(';', StringSplitOptions.RemoveEmptyEntries)) Service(s.Split('=')[0], s.Split('=')[1]);
        foreach (var f in fail.Split(';', StringSplitOptions.RemoveEmptyEntries)) _h.Drivers.Fail.Add(f);
        var ps = Lines(Blocks("features-openssh-server", "-CapabilityStates", $"{Ssh}={cap}", "-ServiceStarts", services, "-FeaturesFail", fail), "features-openssh-server", mode);
        var o = _h.Run("features-openssh-server", Enum.Parse<TweakMode>(mode));
        AssertSame(ps, o, mode == "Apply" ? OutcomeKind.Applied : OutcomeKind.Reverted);
        Assert.False(o.Reboot);
    }

    [Fact]
    public void The_real_file_guard_never_runs_in_a_test() => Assert.Throws<InvalidOperationException>(() => new FileAcl());
}
