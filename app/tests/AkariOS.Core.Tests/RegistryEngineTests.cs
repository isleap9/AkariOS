using AkariOS.Core.Data;
using AkariOS.Core.Registry;
using AkariOS.Core.Tweaks;
using Microsoft.Win32;

namespace AkariOS.Core.Tests;

public sealed class RegistryEngineTests : IDisposable
{
    private const int Win11 = 26100, Win10 = 19045;
    private readonly TestKey _key = new();
    private readonly FakeTrusted _trusted = new();
    private readonly RegistryEngine _reg;

    public RegistryEngineTests() => _reg = new RegistryEngine(_key.Paths, _trusted);

    public void Dispose() => _key.Dispose();

    private static RegistryRow Row(string text) => Loader.ToRow(Assert.IsType<PsHashtable>(PsData.ParseValue(text)))!;

    private sealed class FakeTrusted : ITrustedInstaller
    {
        public int Runs { get; private set; }
        public void Run(Action work) { Runs++; work(); }
    }

    [Theory]
    [InlineData(@"HKLM:\SOFTWARE\X", "HKLM", @"SOFTWARE\X")]
    [InlineData(@"HKCU:\Software\X\", "HKCU", @"Software\X")]
    [InlineData(@"HKEY_LOCAL_MACHINE\SYSTEM", "HKLM", "SYSTEM")]
    [InlineData(@"Registry::HKEY_USERS\.DEFAULT\Control Panel\Mouse", "HKU", @".DEFAULT\Control Panel\Mouse")]
    [InlineData(@"HKLM:\SOFTWARE\Classes\*\shell", "HKLM", @"SOFTWARE\Classes\*\shell")]
    [InlineData("HKLM:", "HKLM", "")]
    public void Splits_the_path_forms_rows_use(string path, string hive, string sub) =>
        Assert.Equal((hive, sub), RegPath.Split(path));

    [Theory]
    [InlineData(@"C:\Windows")]
    [InlineData(@"HKEY_LOCAL_MACHINE:\SOFTWARE")]
    [InlineData(@"Env:\Path")]
    public void Refuses_other_paths(string path) => Assert.Throws<ArgumentException>(() => RegPath.Split(path));

    [Fact]
    public void Nothing_real_can_be_made_in_a_test()
    {
        Assert.Throws<InvalidOperationException>(() => new LiveRegistryPaths(new RealUserSid("S-1-5-21-1")));
        Assert.Throws<InvalidOperationException>(() => new TrustedInstaller());
    }

    [Fact]
    public void Writes_and_reads_each_type()
    {
        const string k = @"HKLM:\SOFTWARE\Akari";
        _reg.SetValue(k, "D", 0xFFC06700u, "DWord");
        _reg.SetValue(k, "Neg", -4167936, "DWord");
        _reg.SetValue(k, "Q", 72000000000UL, "QWord");
        _reg.SetValue(k, "S", "text", "String");
        _reg.SetValue(k, "E", @"%SystemRoot%\x", "ExpandString");
        _reg.SetValue(k, "M", new object?[] { "a", "b" }, "MultiString");
        _reg.SetValue(k, "B", new byte[] { 0x90, 0x12 }, "Binary");
        _reg.SetValue(k, "H", "ab,01", "Binary");
        _reg.SetValue(k, "(default)", "unnamed", "String");

        Assert.Equal(0xFFC06700u, _reg.GetValue(k, "D"));
        Assert.Equal(0xFFC06700u, _reg.GetValue(k, "Neg"));
        Assert.Equal(72000000000UL, _reg.GetValue(k, "Q"));
        Assert.Equal("text", _reg.GetValue(k, "S"));
        Assert.Equal(Environment.ExpandEnvironmentVariables(@"%SystemRoot%\x"), _reg.GetValue(k, "E"));
        Assert.Equal(RegistryValueKind.ExpandString, _reg.GetKind(k, "E"));
        Assert.Equal(new[] { "a", "b" }, _reg.GetValue(k, "M"));
        Assert.Equal(new byte[] { 0x90, 0x12 }, _reg.GetValue(k, "B"));
        Assert.Equal(new byte[] { 0xab, 0x01 }, _reg.GetValue(k, "H"));
        Assert.Equal("unnamed", _reg.GetValue(k, "(default)"));

        _reg.RemoveValue(k, "S");
        _reg.RemoveValue(k, "(default)");
        _reg.RemoveValue(k, "Missing");
        _reg.RemoveValue(@"HKLM:\SOFTWARE\NoSuchKey", "S");
        Assert.Null(_reg.GetValue(k, "S"));
        Assert.Null(_reg.GetValue(k, "(default)"));
        Assert.Null(_reg.GetValue(@"HKLM:\SOFTWARE\NoSuchKey", "S"));
        Assert.Null(_reg.GetKind(k, "S"));
    }

    [Fact]
    public void A_bad_value_says_which()
    {
        var e = Assert.Throws<ArgumentException>(() => _reg.SetValue(@"HKLM:\SOFTWARE\Akari", "D", "lots", "DWord"));
        Assert.Contains(@"HKLM:\SOFTWARE\Akari\D", e.Message);
        Assert.Throws<ArgumentException>(() => _reg.SetValue(@"HKLM:\SOFTWARE\Akari", "D", 1, "Number"));
    }

    [Fact]
    public void Paths_are_literal()
    {
        _reg.SetValue(@"HKLM:\SOFTWARE\Classes\*\shell\x", "V", 1, "DWord");
        _reg.SetValue(@"HKLM:\SOFTWARE\Classes\txtfile\shell\x", "V", 2, "DWord");
        Assert.Equal(1u, _reg.GetValue(@"HKLM:\SOFTWARE\Classes\*\shell\x", "V"));
        _reg.DeleteKey(@"HKLM:\SOFTWARE\Classes\*");
        Assert.False(_reg.KeyExists(@"HKLM:\SOFTWARE\Classes\*"));
        Assert.Equal(2u, _reg.GetValue(@"HKLM:\SOFTWARE\Classes\txtfile\shell\x", "V"));
    }

    [Fact]
    public void Never_deletes_a_whole_hive()
    {
        Assert.Throws<InvalidOperationException>(() => _reg.DeleteKey("HKLM:"));
        Assert.Throws<InvalidOperationException>(() => _reg.DeleteKey(@"HKCU:\"));
        Assert.Throws<InvalidOperationException>(() => _reg.DeleteKey("Registry::HKEY_USERS"));
    }

    private static readonly RegistryRow[] Rows =
    [
        Row(@"@{ Path = 'HKCU:\Software\Akari\Game'; Name = 'Dvr'; Type = 'DWord'; Value = 0; Default = 1 }"),
        Row(@"@{ Path = 'HKCU:\Software\Akari\Game'; Name = 'Gone'; Type = 'String'; Value = 'x'; Default = $null }"),
        Row(@"@{ Path = 'HKLM:\SOFTWARE\Akari\Color'; Name = 'Accent'; Type = 'DWord'; Value = 0xff191919; Default = 0xffd47800 }"),
        Row(@"@{ Path = 'HKLM:\SOFTWARE\Akari\Os'; Name = 'Mode'; Type = 'DWord'; Value = 2; Default = @{ Win10 = 1; Win11 = 0 } }"),
        Row(@"@{ Path = 'HKLM:\SOFTWARE\Akari\Exp'; Name = 'P'; Type = 'ExpandString'; Value = '%SystemRoot%\a'; Default = '%SystemRoot%\b' }"),
        Row(@"@{ Path = 'HKLM:\SOFTWARE\Akari\Bin'; Name = 'Mask'; Type = 'Binary'; Value = [byte[]](0x90, 0x12); Default = [byte[]](0x9e, 0x1e) }"),
        Row(@"@{ Path = 'HKLM:\SOFTWARE\Akari\New'; Value = 'Key'; Default = $null }"),
        Row(@"@{ Path = 'HKLM:\SOFTWARE\Akari\Old'; Value = $null; Default = 'Key' }"),
    ];

    [Fact]
    public void Apply_then_revert_rows()
    {
        _reg.CreateKey(@"HKLM:\SOFTWARE\Akari\Old\Inside");
        Assert.Equal(TweakState.Custom, _reg.State(Rows, Win11));

        _reg.Invoke(Rows, TweakMode.Apply, Win11);
        Assert.Equal(TweakState.Optimized, _reg.State(Rows, Win11));
        Assert.Equal(0xff191919u, _reg.GetValue(@"HKLM:\SOFTWARE\Akari\Color", "Accent"));
        Assert.True(_reg.KeyExists(@"HKLM:\SOFTWARE\Akari\New"));
        Assert.False(_reg.KeyExists(@"HKLM:\SOFTWARE\Akari\Old"));

        _reg.Invoke(Rows, TweakMode.Revert, Win11);
        Assert.Equal(TweakState.Default, _reg.State(Rows, Win11));
        Assert.Null(_reg.GetValue(@"HKCU:\Software\Akari\Game", "Gone"));
        Assert.Equal(0u, _reg.GetValue(@"HKLM:\SOFTWARE\Akari\Os", "Mode"));
        Assert.False(_reg.KeyExists(@"HKLM:\SOFTWARE\Akari\New"));
        Assert.True(_reg.KeyExists(@"HKLM:\SOFTWARE\Akari\Old"));

        // the same values are Custom on Windows 10, whose Default is 1
        Assert.Equal(TweakState.Custom, _reg.State(Rows, Win10));
        _reg.Invoke(Rows, TweakMode.Revert, Win10);
        Assert.Equal(1u, _reg.GetValue(@"HKLM:\SOFTWARE\Akari\Os", "Mode"));
        Assert.Equal(TweakState.Default, _reg.State(Rows, Win10));

        _reg.SetValue(@"HKCU:\Software\Akari\Game", "Dvr", 5, "DWord");
        Assert.Equal(TweakState.Custom, _reg.State(Rows, Win10));
    }

    [Fact]
    public void Trusted_rows_write_hklm_as_trustedinstaller_only()
    {
        _reg.Invoke(Rows, TweakMode.Apply, Win11, asTrusted: true);
        Assert.Equal(1, _trusted.Runs);
        Assert.Equal(TweakState.Optimized, _reg.State(Rows, Win11));
        _reg.Invoke(Rows.Take(2), TweakMode.Apply, Win11, asTrusted: true);
        Assert.Equal(1, _trusted.Runs);
        Assert.Throws<InvalidOperationException>(() => new RegistryEngine(_key.Paths).Invoke(Rows, TweakMode.Apply, Win11, asTrusted: true));
    }

    [Theory]
    [InlineData(null, null, true)]
    [InlineData(1u, null, false)]
    [InlineData(null, 0, false)]
    [InlineData(4294967295u, -1, true)]
    [InlineData(38u, 0x26, true)]
    [InlineData("1", 1, true)]
    [InlineData("Abc", "abc", true)]
    [InlineData(18446744073709551615UL, -1L, true)]
    public void Matches_as_Test_AkariRegMatch(object? current, object? expected, bool match) =>
        Assert.Equal(match, RegistryEngine.Matches(current, expected));

    [Fact]
    public void Bytes_and_lists_match_item_by_item()
    {
        Assert.True(RegistryEngine.Matches(new byte[] { 1, 2 }, new byte[] { 1, 2 }));
        Assert.True(RegistryEngine.Matches(new byte[] { 1, 2 }, new object?[] { 1, 2 }));
        Assert.False(RegistryEngine.Matches(new byte[] { 1, 2 }, new byte[] { 1, 3 }));
        Assert.True(RegistryEngine.Matches(new[] { "a", "b" }, new object?[] { "a", "b" }));
    }
}
