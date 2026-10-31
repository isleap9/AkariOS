using AkariOS.Core.Data;
using AkariOS.Core.Registry;
using AkariOS.Core.Tweaks;
using Microsoft.Win32;

namespace AkariOS.Core.Tests;

/// <summary>
/// RegistryEngine against the PowerShell app's Core\Registry.ps1 on the same rows in the same test key: what one
/// writes, the other reads as the same State (Oracle/Invoke-Registry.ps1).
/// </summary>
public sealed class RegistryOracleTests : IDisposable
{
    private readonly TestKey _key = new();
    private readonly string _rowsFile = Path.Combine(Path.GetTempPath(), $"akari-rows-{Guid.NewGuid():N}.ps1");

    public void Dispose()
    {
        _key.Dispose();
        File.Delete(_rowsFile);
    }

    /// <summary>Paths here are the test key's own, read as HKCU by both apps.</summary>
    private sealed class HkcuOnly : IRegistryPaths
    {
        public RegKeyPath Resolve(string path)
        {
            var (hive, sub) = RegPath.Split(path);
            if (hive != "HKCU" || !sub.StartsWith(@"Software\AkariTest\", StringComparison.OrdinalIgnoreCase)) throw new ArgumentException($"not the test key: {path}");
            return new RegKeyPath(RegistryHive.CurrentUser, sub);
        }
    }

    private string Rows(string root) => $$"""
        @(
            @{ Path = '{{root}}\Game'; Name = 'Dvr'; Type = 'DWord'; Value = 0; Default = 1 }
            @{ Path = '{{root}}\Game'; Name = 'Gone'; Type = 'String'; Value = 'x'; Default = $null }
            @{ Path = '{{root}}\Game'; Name = '(default)'; Type = 'String'; Value = 'on'; Default = $null }
            @{ Path = '{{root}}\Color'; Name = 'Accent'; Type = 'DWord'; Value = 0xff191919; Default = 0xffd47800 }
            @{ Path = '{{root}}\Color'; Name = 'Big'; Type = 'QWord'; Value = [uint64]72000000000; Default = [uint64]10000 }
            @{ Path = '{{root}}\Exp'; Name = 'P'; Type = 'ExpandString'; Value = '%SystemRoot%\a'; Default = '%SystemRoot%\b' }
            @{ Path = '{{root}}\Bin'; Name = 'Mask'; Type = 'Binary'; Value = [byte[]](0x90, 0x12, 0x03); Default = [byte[]](0x9e, 0x1e, 0x07) }
            @{ Path = '{{root}}\Classes\*\shell\x'; Name = 'V'; Type = 'String'; Value = 'all files'; Default = $null }
            @{ Path = '{{root}}\New'; Value = 'Key'; Default = $null }
            @{ Path = '{{root}}\Old'; Value = $null; Default = 'Key' }
        )
        """;

    private string PowerShell(string mode) =>
        Oracle.Run("Invoke-Registry.ps1", "-Src", Repo.Src, "-Rows", _rowsFile, "-Mode", mode).GetProperty("State").GetString()!;

    [Fact]
    public void What_one_app_writes_the_other_reads_the_same()
    {
        var root = $@"HKCU:\{_key.Root}";
        File.WriteAllText(_rowsFile, Rows(root));
        var rows = PsSemantics.AsList(PsData.ParseValue(Rows(root))).Select(r => Loader.ToRow((PsHashtable)r!)!).ToList();
        var reg = new RegistryEngine(new HkcuOnly());
        var build = Environment.OSVersion.Version.Build;

        reg.CreateKey($@"{root}\Old\Inside");
        Assert.Equal("Custom", PowerShell("State"));
        Assert.Equal(TweakState.Custom, reg.State(rows, build));

        reg.Invoke(rows, TweakMode.Apply, build);
        Assert.Equal("Optimized", PowerShell("State"));

        Assert.Equal("Default", PowerShell("Revert"));
        Assert.Equal(TweakState.Default, reg.State(rows, build));

        Assert.Equal("Optimized", PowerShell("Apply"));
        Assert.Equal(TweakState.Optimized, reg.State(rows, build));

        reg.Invoke(rows, TweakMode.Revert, build);
        Assert.Equal("Default", PowerShell("State"));

        reg.SetValue($@"{root}\Color", "Accent", 7, "DWord");
        Assert.Equal("Custom", PowerShell("State"));
        Assert.Equal(TweakState.Custom, reg.State(rows, build));
    }
}
