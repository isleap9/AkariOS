using AkariOS.Core.Apps;
using AkariOS.Core.Iso;
using static AkariOS.Core.Tests.IsoBuildOracleTests;

namespace AkariOS.Core.Tests;

/// <summary>IsoBuild where the native app differs on purpose from the port or the oracle leaves it out: AkariOS as the
/// running exe, the answer file, the ADK's setup, the hive unload retries, the image reads.</summary>
public sealed class IsoBuildTests
{
    [Fact]
    public void Copies_the_running_exe_into_the_image_with_its_shortcuts()
    {
        var c = Case(x => Choices(x)["AkariOS"] = true);
        using var s = new Side(c);
        var copied = "";
        IsoFakes? fakes = null;
        var o = Cs(s, c, f =>
        {
            fakes = f;
            f.OnCommit = mount =>
            {
                var exe = Path.Combine(mount, "AkariOS", "AkariOS-Native.exe");
                if (copied.Length == 0 && File.Exists(exe)) copied = File.ReadAllText(exe);
            };
        });
        Assert.StartsWith("Action=Build;Ok=true", o.Results[1]);
        Assert.Equal("exe", copied);
        Assert.Equal(
        [
            @"<root>\out\AkariIso\Mount\ProgramData\Microsoft\Windows\Start Menu\Programs\AkariOS.lnk|C:\AkariOS\AkariOS-Native.exe|C:\AkariOS",
            @"<root>\out\AkariIso\Mount\Users\Public\Desktop\AkariOS.lnk|C:\AkariOS\AkariOS-Native.exe|C:\AkariOS",
        ], fakes!.Shortcuts);
        Assert.Contains("Adding AkariOS to the image", o.Log);
    }

    [Fact]
    public void Leaves_akarios_out_without_an_exe()
    {
        var c = Case();
        using var s = new Side(c);
        IsoFakes? fakes = null;
        var o = Cs(s, c, f => fakes = f);
        Assert.DoesNotContain("Adding AkariOS to the image", o.Log);
        Assert.Empty(fakes!.Shortcuts);
    }

    [Fact]
    public void Puts_the_answer_file_at_the_root_of_the_iso()
    {
        var c = Case(x => Choices(x)["Unattend"] = "<unattend/>");
        using var s = new Side(c);
        var answer = "";
        Cs(s, c, f => f.OnOscdimg = () => answer = File.ReadAllText(Path.Combine(s.Root, @"out\AkariIso\Media\autounattend.xml")));
        Assert.Equal("<unattend/>", answer);
    }

    [Fact]
    public void Installs_the_adk_deployment_tools_when_oscdimg_is_missing()
    {
        var c = Case();
        using var s = new Side(c);
        IsoFakes? fakes = null;
        var o = Cs(s, c, f =>
        {
            fakes = f;
            var oscdimg = Path.Combine(f.Parts.ProgramFilesX86, @"Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe");
            File.Delete(oscdimg);
            f.OnExe = (path, _) => { if (Path.GetFileName(path) == "akari-adksetup.exe") File.WriteAllText(oscdimg, ""); };
        });
        Assert.StartsWith("Action=Build;Ok=true", o.Results[1]);
        Assert.Equal([@"https://go.microsoft.com/fwlink/?linkid=2196127|<root>\temp\akari-adksetup.exe"], fakes!.Downloads);
        var setup = fakes.Runs.Single(r => Path.GetFileName(r.Path) == "akari-adksetup.exe");
        Assert.Equal("/quiet /norestart /features OptionId.DeploymentTools", setup.Args);
        Assert.True(setup.Wait);
        Assert.False(setup.Capture);
        Assert.False(File.Exists(Path.Combine(s.Root, @"temp\akari-adksetup.exe")));
        Assert.Single(o.Calls, x => x.StartsWith("Oscdimg ", StringComparison.Ordinal));
    }

    [Fact]
    public void Fails_before_mounting_when_the_adk_will_not_install()
    {
        var c = Case();
        using var s = new Side(c);
        var o = Cs(s, c, f => File.Delete(Path.Combine(f.Parts.ProgramFilesX86, @"Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe")));
        Assert.Equal("Action=Build;Ok=false;Path=;Message=The Windows ADK Deployment Tools did not install (oscdimg.exe is missing).", o.Results[1]);
        Assert.DoesNotContain(o.Calls, x => x.StartsWith("Mount ", StringComparison.Ordinal));
    }

    [Fact]
    public void Reports_progress_per_step_then_done()
    {
        var c = Case();
        using var s = new Side(c);
        var o = Cs(s, c);
        // Adk, Mount, Registry, Files, NetFx3, Cleanup, Commit, Compress, Boot, Iso, Tidy
        Assert.Equal("0/11 Getting the ISO tool ready (Windows ADK)", o.Progress[0]);
        Assert.Equal("1/11 Mounting Windows 11 Pro", o.Progress[1]);
        Assert.Equal("10/11 Removing the work folder", o.Progress[10]);
        Assert.Equal("11/11 Done", o.Progress[^1]);
        Assert.Equal(12, o.Progress.Count);
    }

    [Fact]
    public void Tries_a_hive_unload_three_times_with_a_pause()
    {
        var c = Case(x => x["Actions"] = new[] { "Leftover" });
        c["Marker"] = new { Mount = @"<root>\m", Image = "", Index = 0 };
        using var s = new Side(c);
        var sleeps = new List<int>();
        var o = Cs(s, c, f => { f.UnloadFailures = 3; f.Parts = f.Parts with { Sleep = sleeps.Add }; });
        Assert.Equal(["HiveUnload SOFTWARE", "HiveUnload SOFTWARE", "HiveUnload SOFTWARE", "HiveUnload SYSTEM"], o.Calls.Take(4));
        Assert.Equal([500, 500], sleeps);
    }

    [Fact]
    public void Lists_the_image_apps_without_frameworks_and_only_installed_capabilities()
    {
        var c = Case();
        using var s = new Side(c);
        var f = new IsoFakes(s, c);
        var b = new IsoBuild(f.Parts);
        Assert.Equal(["Microsoft.BingNews", "Microsoft.SecHealthUI", "Microsoft.Copilot", "Microsoft.WindowsCalculator"], b.Apps("m").Select(a => a.Name));
        var image = new CapabilitiesImage(f);
        Assert.Equal(["A"], new IsoBuild(f.Parts with { Image = image }).Capabilities("m").Select(x => x.Name));
    }

    private sealed class CapabilitiesImage(IImage inner) : IImage
    {
        public IReadOnlyList<WimImage> Images(string wim) => inner.Images(wim);
        public void Export(string source, int index, string dest, string compression) => inner.Export(source, index, dest, compression);
        public void Mount(string wim, int index, string mount) => inner.Mount(wim, index, mount);
        public void Commit(string mount) => inner.Commit(mount);
        public void Discard(string mount) => inner.Discard(mount);
        public IReadOnlyList<ImageApp> ProvisionedApps(string mount) => inner.ProvisionedApps(mount);
        public IReadOnlyList<DismItem> Features(string mount) => inner.Features(mount);
        public IReadOnlyList<DismItem> Capabilities(string mount) => [new("A", "Installed"), new("B", "NotPresent"), new("C", "Staged")];
        public IReadOnlyList<DismItem> Packages(string mount) => inner.Packages(mount);
        public int Remove(string mount, string kind, string name) => inner.Remove(mount, kind, name);
        public int Dism(IReadOnlyList<string> arguments) => inner.Dism(arguments);
    }
}
