using AkariOS.Core.Inject;
using AkariOS.Core.Pipeline;
using AkariOS.Core.Wim;
using ManagedWimLib;
using Microsoft.Extensions.Logging.Abstractions;
using WimLib = ManagedWimLib.Wim;
using Xunit;

namespace AkariOS.Tests;

/// <summary>
/// End-to-end test of direct WIM servicing: builds a tiny real WIM via wimlib,
/// injects payload through WimService, then re-opens and verifies the files
/// landed in \Windows\Setup\Scripts inside the image.
/// </summary>
public sealed class WimServiceTests : IDisposable
{
    private readonly string _dir = Path.Combine(Path.GetTempPath(), "AkariOS.Tests", Path.GetRandomFileName());

    public WimServiceTests() => Directory.CreateDirectory(_dir);

    [Fact]
    public void InjectPayload_BakesFilesIntoImage()
    {
        WimService.EnsureInitialized();

        // 1) Build a tiny source tree + a minimal one-image WIM.
        var srcTree = Path.Combine(_dir, "tree");
        Directory.CreateDirectory(Path.Combine(srcTree, "Windows", "System32"));
        File.WriteAllText(Path.Combine(srcTree, "Windows", "System32", "marker.txt"), "wim");

        var wimPath = Path.Combine(_dir, "sources", "install.wim");
        Directory.CreateDirectory(Path.GetDirectoryName(wimPath)!);
        using (var wim = WimLib.CreateNewWim(CompressionType.None))
        {
            wim.AddImage(srcTree, "Windows 11 Pro", null, AddFlags.None);
            wim.Write(wimPath, WimLib.AllImages, WriteFlags.None, WimLib.DefaultThreads);
        }

        // 2) Payload: one ps1 + one txt.
        var payload = new List<string>
        {
            Path.Combine(_dir, "WinSux.ps1"),
            Path.Combine(_dir, "extra.txt"),
        };
        File.WriteAllText(payload[0], "Write-Host 'debloat'");
        File.WriteAllText(payload[1], "payload");

        // 3) Service it.
        var service = new WimService(NullLogger<WimService>.Instance);
        Assert.True(service.HasInstallWim(_dir));

        var images = service.ListImages(_dir);
        var image = Assert.Single(images);
        Assert.Equal("Windows 11 Pro", image.Name);

        var reports = new List<ProgressReport>();
        service.InjectPayload(_dir, payload, [image.Index],
            new Progress<ProgressReport>(reports.Add));

        // 4) Re-open and verify the injected files are readable from the image.
        using var verify = WimLib.OpenWim(wimPath, OpenFlags.None);
        Assert.True(verify.FileExists(image.Index, @"\Windows\Setup\Scripts\WinSux.ps1"));
        Assert.True(verify.FileExists(image.Index, @"\Windows\Setup\Scripts\extra.txt"));
        Assert.True(verify.FileExists(image.Index, @"\Windows\Setup\Scripts\SetupComplete.cmd"));

        // SetupComplete.cmd must register the RunOnce trigger.
        var extractDir = Path.Combine(_dir, "extract");
        verify.ExtractPath(image.Index, extractDir, @"\Windows\Setup\Scripts\SetupComplete.cmd", ExtractFlags.NoPreserveDirStructure);
        var cmd = File.ReadAllText(Path.Combine(extractDir, "SetupComplete.cmd"));
        Assert.Contains(OemInjectStep.RunOnceValueName, cmd);
    }

    [Fact]
    public void ListImages_MultiEdition_ReturnsAllNames()
    {
        WimService.EnsureInitialized();

        var srcTree = Path.Combine(_dir, "multi");
        Directory.CreateDirectory(srcTree);

        var wimPath = Path.Combine(_dir, "multi.wim");
        using (var wim = WimLib.CreateNewWim(CompressionType.None))
        {
            wim.AddImage(srcTree, "Home", null, AddFlags.None);
            wim.AddImage(srcTree, "Pro", null, AddFlags.None);
            wim.Write(wimPath, WimLib.AllImages, WriteFlags.None, WimLib.DefaultThreads);
        }

        // ListImages expects the file at <staging>\sources\install.wim — stage it there.
        var staging = Path.Combine(_dir, "stage");
        Directory.CreateDirectory(Path.Combine(staging, "sources"));
        File.Copy(wimPath, Path.Combine(staging, "sources", "install.wim"), overwrite: true);

        var service = new WimService(NullLogger<WimService>.Instance);
        var names = service.ListImages(staging).Select(i => i.Name).ToList();
        Assert.Equal(["Home", "Pro"], names);
    }

    public void Dispose()
    {
        try { Directory.Delete(_dir, recursive: true); }
        catch (IOException) { }
    }
}
