using AkariOS.Core.Inject;
using AkariOS.Core.Pipeline;
using Xunit;

namespace AkariOS.Tests;

public class OemInjectStepTests : IDisposable
{
    private readonly string _tmp = Path.Combine(Path.GetTempPath(), "AkariOSTests", Path.GetRandomFileName());

    public void Dispose() => Directory.Delete(_tmp, recursive: true);

    [Fact]
    public async Task Copies_payload_and_writes_setupcomplete()
    {
        var staging = Path.Combine(_tmp, "staging");
        Directory.CreateDirectory(staging);
        var payload = Path.Combine(_tmp, "WinSux.ps1");
        await File.WriteAllTextAsync(payload, "# tweaks");

        var step = new OemInjectStep();
        var ctx = new BuildContext { StagingDirectory = staging };
        await step.ExecuteAsync(
            new InjectionOptions { SourceIsoPath = "x", PayloadFiles = [payload] },
            ctx, new Progress<ProgressReport>(_ => { }), CancellationToken.None);

        var scripts = Path.Combine(staging, OemInjectStep.ScriptsRelativePath);
        Assert.True(File.Exists(Path.Combine(scripts, "WinSux.ps1")));
        // SetupComplete must NOT run WinSux directly — only register the RunOnce hook.
        var cmd = File.ReadAllText(Path.Combine(scripts, OemInjectStep.BootstrapCmdFileName));
        Assert.Contains(OemInjectStep.RunOnceValueName, cmd);
        Assert.DoesNotContain(".ps1", cmd, StringComparison.OrdinalIgnoreCase);
        Assert.True(File.Exists(Path.Combine(scripts, OemInjectStep.LogonCmdFileName)));
        var logon = File.ReadAllText(Path.Combine(scripts, OemInjectStep.LogonCmdFileName));
        Assert.Contains("WinSux.ps1", logon);
        Assert.Contains("-ExecutionPolicy Bypass", logon);
        // $OEM$ path must be literal (no env expansion in the name)
        Assert.Contains("$OEM$", OemInjectStep.ScriptsRelativePath);
    }

    [Fact]
    public async Task Missing_payload_throws()
    {
        var step = new OemInjectStep();
        var ctx = new BuildContext { StagingDirectory = _tmp };
        await Assert.ThrowsAsync<FileNotFoundException>(() => step.ExecuteAsync(
            new InjectionOptions { SourceIsoPath = "x", PayloadFiles = ["C:\\nope.ps1"] },
            ctx, new Progress<ProgressReport>(_ => { }), CancellationToken.None));
    }
}
