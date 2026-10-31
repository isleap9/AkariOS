using System.IO;
using AkariOS.Core;
using AkariOS.Core.Machine;
using AkariOS.Core.Presets;
using AkariOS.Core.Registry;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;
using Microsoft.Win32;

namespace AkariOS.App.Tests;

/// <summary>
/// The CLI on fixture Tweaks and a test key (rule 12: never the machine's registry; the real engine can't even be
/// made here). Every run is in-process: the exe itself is never started.
/// </summary>
public sealed class CliTests : IDisposable
{
    private readonly string _root = $@"Software\AkariTest\{Guid.NewGuid():N}";
    private readonly string _dir = Path.Combine(Path.GetTempPath(), $"akari-cli-{Guid.NewGuid():N}");
    private readonly MemoryLog _log = new();
    private readonly MemorySourceFiles _files = new();
    private bool _admin = true;

    public CliTests()
    {
        Tweak("Optimize", "Gaming", "gaming-a", "Registry = @( @{ Path = 'HKCU:\\Software\\Akari'; Name = 'A'; Type = 'DWord'; Value = 0; Default = 1 } )");
        Tweak("Optimize", "Gaming", "gaming-b", "Reboot = $true; Registry = @( @{ Path = 'HKCU:\\Software\\Akari'; Name = 'B'; Type = 'DWord'; Value = 0; Default = 1 } )");
        Tweak("Customize", "Theme", "theme-code", "Apply = { Set-Thing }; Revert = { Reset-Thing }");
        _files.Add("src/Presets/AkariOS.json", """{ "Name": "AkariOS", "Phases": [ { "Name": "1", "Tweaks": [ "gaming-a" ] }, { "Name": "2", "Boot": "SafeMode", "Tweaks": [] } ] }""");
        _files.Add("src/Presets/Mine.json", """{ "Name": "Mine", "Tweaks": [ "gaming-a", "gaming-b", "not-here" ] }""");
    }

    public void Dispose()
    {
        using var hkcu = RegistryKey.OpenBaseKey(RegistryHive.CurrentUser, RegistryView.Registry64);
        hkcu.DeleteSubKeyTree(_root, throwOnMissingSubKey: false);
        if (Directory.Exists(_dir)) Directory.Delete(_dir, recursive: true);
    }

    private void Tweak(string section, string category, string id, string body) =>
        _files.Add($"src/Tweaks/{section}/{category}/{id}.ps1", $"@{{ Id = '{id}'; Name = '{id}'; Section = '{section}'; Category = '{category}'; Risk = 'Safe'; Description = 'x'\n{body}\n}}");

    private sealed class Pc : ISystemInfo
    {
        public int Build => 26100;
        public string Edition => "Professional";
        public Chassis Chassis => Chassis.Desktop;
        public IReadOnlyList<Gpu> Gpus => [];
        public IReadOnlyList<string> GpuDevices => [];
    }

    private sealed class NoExplorer : IExplorer
    {
        public void Restart() { }
    }

    private RegistryEngine Registry => new(new RedirectedRegistryPaths(_root));

    private Engine Make() => new()
    {
        Files = _files,
        Registry = Registry,
        System = new Pc(),
        Log = _log,
        Remembered = new JsonRememberedState(Path.Combine(_dir, "state.json")),
        Explorer = new NoExplorer(),
        Presets = new PresetStore(_files, Path.Combine(_dir, "presets"), Path.Combine(_dir, "lastused.json"), _log),
        Codes = new Dictionary<string, ITweakCode>(),
        IsAdmin = () => _admin,
    };

    private (int Code, string Out, string Err) Cli(params string[] args)
    {
        var o = new StringWriter();
        var e = new StringWriter();
        var code = App.Cli.Run(args, o, e, Make);
        return (code, o.ToString().Replace("\r\n", "\n"), e.ToString());
    }

    [Fact]
    public void Prints_the_version_without_an_engine()
    {
        var o = new StringWriter();
        Assert.Equal(0, App.Cli.Run(["--version"], o, new StringWriter(), () => throw new InvalidOperationException("no engine for --version")));
        Assert.Equal($"AkariOS-Native {AkariInfo.Version}", o.ToString().Trim());
    }

    [Fact]
    public void Lists_every_tweak_with_its_state()
    {
        var (code, output, _) = Cli("--list");
        Assert.Equal(0, code);
        var lines = output.TrimEnd().Split('\n');
        Assert.StartsWith("Id ", lines[0]);
        Assert.EndsWith("State   Native", lines[0]);
        Assert.Equal(["theme-code", "gaming-a", "gaming-b"], lines.Skip(2).Select(l => l.Split(' ')[0]));
        Assert.Matches(@"^gaming-a\s+Toggle\s+Optimize\s+Gaming\s+Safe\s+Custom\s+yes$", lines[3]);
        Assert.Matches(@"^theme-code\s+.*\s+Unknown\s+no$", lines[2]);
    }

    [Fact]
    public void Applies_and_reverts_with_outcome_lines()
    {
        var (code, output, _) = Cli("--apply", "gaming-a,gaming-b");
        Assert.Equal(0, code);
        Assert.Equal("Applied   gaming-a\nApplied   gaming-b\nReboot pending\n", output);
        Assert.Equal(0u, Registry.GetValue(@"HKCU:\Software\Akari", "A"));
        Assert.Equal(["Applied   gaming-a", "Applied   gaming-b"], _log.FileLines.Where(l => !l.StartsWith("Warning:", StringComparison.Ordinal)));

        (code, output, _) = Cli("--revert", "gaming-a", "gaming-b");
        Assert.Equal((0, "Reverted  gaming-a\nReverted  gaming-b\nReboot pending\n"), (code, output));
        Assert.Equal(("Already   gaming-a\n"), Cli("--revert", "gaming-a").Out);
    }

    [Fact]
    public void A_failure_exits_1()
    {
        var (code, output, _) = Cli("--apply", "no-such-tweak,theme-code");
        Assert.Equal(1, code);
        Assert.Contains("Failed    no-such-tweak  Unknown tweak id", output);
        Assert.Contains("Failed    theme-code  only the PowerShell app can run it yet", output);
    }

    [Fact]
    public void Runs_a_preset_and_warns_about_unknown_ids()
    {
        var (code, output, error) = Cli("--preset", "mine");
        Assert.Equal(0, code);
        Assert.StartsWith("Applied   gaming-a\nApplied   gaming-b\n", output);
        Assert.Contains("Warning: preset Mine: 'not-here' is not a Tweak here", error);
        (code, output, _) = Cli("--revert-preset", "Mine");
        Assert.Equal((0, "Reverted  gaming-b\nReverted  gaming-a\nReboot pending\n"), (code, output));
    }

    [Fact]
    public void A_preset_in_phases_waits_for_runs_in_phases()
    {
        var (code, output, error) = Cli("--preset", "AkariOS");
        Assert.Equal((2, ""), (code, output));
        Assert.Contains("runs in 2 phases", error);
        Assert.Null(Registry.GetValue(@"HKCU:\Software\Akari", "A"));
    }

    [Theory]
    [InlineData("--preset", "nothing", "No preset 'nothing'")]
    [InlineData("--apply", "", "--apply needs Tweak ids")]
    [InlineData("--nope", "", "Unknown option '--nope'")]
    public void Usage_errors_exit_2(string option, string arg, string message)
    {
        var (code, _, error) = arg.Length == 0 ? Cli(option) : Cli(option, arg);
        Assert.Equal(2, code);
        Assert.Contains(message, error);
    }

    [Fact]
    public void Changes_need_an_elevated_console()
    {
        _admin = false;
        var (code, _, error) = Cli("--apply", "gaming-a");
        Assert.Equal(2, code);
        Assert.Contains("elevated", error);
        Assert.Null(Registry.GetValue(@"HKCU:\Software\Akari", "A"));
        Assert.Equal(0, Cli("--list").Code);
    }

    [Fact]
    public void Loader_errors_go_to_stderr_and_akari_log()
    {
        _files.Add("src/Tweaks/Optimize/Gaming/broken.ps1", "@{ Id = 'Broken' }");
        var (code, _, error) = Cli("--list");
        Assert.Equal(0, code);
        Assert.Contains("Error: src/Tweaks/Optimize/Gaming/broken.ps1: Optimize/Gaming/broken.ps1: missing Name", error);
        Assert.Contains(_log.FileLines, l => l.Contains("broken.ps1"));
    }

    [Fact]
    public void The_live_engine_cant_be_made_in_a_test() =>
        Assert.Throws<InvalidOperationException>(() => Engine.Live(new Dictionary<string, ITweakCode>(), new MemoryLog()));
}
