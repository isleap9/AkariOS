using AkariOS.Core.Runs;
using static AkariOS.Tweaks.Tests.BlockLines;

namespace AkariOS.Tweaks.Tests.Tools;

/// <summary>Tools/Fixes (winutil's Fixes, W1) against their PowerShell blocks: the same programs and exit codes, the
/// same services, registry values and files, the same console lines.</summary>
public sealed partial class ToolsTests
{
    private static readonly string[] UpdateServices = ["BITS", "wuauserv", "appidsvc", "cryptsvc"];

    [Fact]
    public void The_network_reset_resets_winsock_and_ip_and_wants_a_restart()
    {
        var ps = Lines(Blocks("tools-fix-network"), "tools-fix-network", "Apply");
        var o = Apply("tools-fix-network");
        Assert.Equal(OutcomeKind.Applied, o.Kind);
        Assert.True(o.Reboot);
        Assert.Equal(PsDid(ps), CsDid());
        Assert.Equal([@"run %SystemRoot%\System32\netsh.exe|int ip reset", @"run %SystemRoot%\System32\netsh.exe|winsock reset"], CsDid());
        AssertLogged(ps);
    }

    [Fact]
    public void The_Windows_Update_reset_does_winutils_steps_and_keeps_other_policies()
    {
        const string policy = @"HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate";
        _h.Set(policy, "ExcludeWUDriversInQualityUpdate", 1u, "DWord");
        _h.Set(@"HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings", "DeferQualityUpdatesPeriodInDays", 7u, "DWord");
        _h.Set(@"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate", "SusClientId", "x", "String");
        // another AkariOS policy stays (winutil's blanket wipe is left out)
        _h.Set(@"HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection", "AllowTelemetry", 0u, "DWord");
        foreach (var s in UpdateServices) _h.Set($@"HKLM:\SYSTEM\CurrentControlSet\Services\{s}", "Start", 4u, "DWord");
        Files(@"%ProgramData%\Microsoft\Network\Downloader\qmgr0.dat", @"%SystemRoot%\SoftwareDistribution\Download\a.cab",
            @"%SystemRoot%\SoftwareDistribution\Download.bak\old.cab", @"%SystemRoot%\WindowsUpdate.log", @"%SystemRoot%\SoftwareDistribution\DataStore\DataStore.edb");

        var ps = Lines(Blocks("tools-fix-windows-update"), "tools-fix-windows-update", "Apply");
        var o = Apply("tools-fix-windows-update");
        Assert.Equal(OutcomeKind.Applied, o.Kind);
        Assert.True(o.Reboot);

        Assert.Equal(PsDid(ps), CsDid());
        Assert.Equal(36, CsDid().Count(l => l.Contains("regsvr32.exe|/s ", StringComparison.Ordinal)));
        Assert.Contains(@"run %SystemRoot%\System32\bitsadmin.exe|/reset /allusers", CsDid());
        AssertWrites(_h, ps);
        Assert.Equal(13, Of(ps, "remove").Count);
        Assert.Equal(0u, _h.Get(@"HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection", "AllowTelemetry"));
        Assert.All(UpdateServices, s => Assert.Equal(3u, _h.Get($@"HKLM:\SYSTEM\CurrentControlSet\Services\{s}", "Start")));
        Assert.Equal(Of(ps, "stopservice", "startservice").Select(l => l.Replace("stopservice ", "stop ").Replace("startservice ", "start ")), _h.Services.Calls);
        // the same files left on both sides: the cache moved to Download.bak (an old one replaced), the queue and log gone
        string[] left = [@"%SystemRoot%\SoftwareDistribution\Download.bak\a.cab", @"%SystemRoot%\SoftwareDistribution\DataStore\DataStore.edb"];
        Assert.Equal(_ps.Tree(), _cs.Tree());
        Assert.All(left, f => Assert.Contains(f, _cs.Tree()));
        Assert.DoesNotContain(_cs.Tree(), f => f.EndsWith("qmgr0.dat", StringComparison.Ordinal) || f.EndsWith("old.cab", StringComparison.Ordinal) || f.EndsWith("WindowsUpdate.log", StringComparison.Ordinal));
        AssertLogged(ps);
    }

    [Theory]
    [InlineData("", "")]
    [InlineData("chkdsk.exe=1;dism.exe=3010", "")]
    [InlineData("chkdsk.exe=3", "Checking the disk for errors failed (exit code 3)")]
    [InlineData("sfc.exe=1", "Scanning protected system files failed (exit code 1)")]
    public void The_system_repair_runs_chkdsk_sfc_and_DISM_with_winutils_exit_codes(string codes, string failure)
    {
        var map = codes.Split(';', StringSplitOptions.RemoveEmptyEntries).Select(c => c.Split('=')).ToDictionary(c => c[0], c => int.Parse(c[1]), StringComparer.OrdinalIgnoreCase);
        _h.Exe.Result = (path, _) => new(map.GetValueOrDefault(Path.GetFileName(path)), "");
        var ps = Lines(Blocks("tools-system-repair", "-ExeCodes", codes.Length > 0 ? codes : ";"), "tools-system-repair", "Apply");
        var o = Apply("tools-system-repair");
        Assert.Equal(PsDid(ps), CsDid());
        AssertLogged(ps);
        if (failure.Length == 0)
        {
            Assert.Equal(OutcomeKind.Applied, o.Kind);
            Assert.Equal(3, CsDid().Count);
        }
        else
        {
            Assert.Equal(OutcomeKind.Failed, o.Kind);
            Assert.Equal($"throw {failure}", ps[^1]);
            Assert.Contains(failure, o.Message);
        }
    }

    [Fact]
    public void The_winget_reinstall_installs_App_Installer_again_even_when_winget_works()
    {
        var ps = Lines(Blocks("tools-fix-winget"), "tools-fix-winget", "Apply");
        Assert.Equal(["wingettool True"], ps);
        _h.Http.ValidZips = true;
        Assert.Equal(OutcomeKind.Applied, Apply("tools-fix-winget").Kind);
        // App Installer's dependencies and bundle from winget-cli's release, then added
        Assert.Contains(_h.Http.Saved, s => s.Contains("Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle", StringComparison.Ordinal));
        Assert.Contains(_h.Log.Lines, l => l == "winget: installing App Installer again");
    }

    [Fact]
    public void AutoLogon_opens_Sysinternals_Autologon_installing_it_first_when_missing()
    {
        var ps = Lines(Blocks("tools-autologon"), "tools-autologon", "Apply");
        Assert.Equal(OutcomeKind.Failed, Apply("tools-autologon").Kind);
        Assert.Equal(["winget Microsoft.Sysinternals.Autologon winget"], Of(ps, "winget"));
        Assert.Equal(Of(ps, "winget"), _h.Winget.Installs);

        Files(@"%ProgramFiles%\Sysinternals\Autologon64.exe");
        _h.Winget.Installs.Clear();
        var ps2 = Lines(Blocks("tools-autologon"), "tools-autologon", "Apply");
        Assert.Equal(OutcomeKind.Applied, Apply("tools-autologon").Kind);
        Assert.Equal(PsDid(ps2), CsDid());
        Assert.Equal(@"start %ProgramFiles%\Sysinternals\Autologon64.exe|", CsDid().Single());
    }
}
