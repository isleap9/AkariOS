using AkariOS.Core.Data;

namespace AkariOS.Core.Tests;

public class PsDataTests
{
    private static PsHashtable Table(string text) => Assert.IsType<PsHashtable>(PsData.ParseValue(text));

    [Fact]
    public void Reads_a_tweak_shaped_hashtable()
    {
        var t = Table("""
            # a comment
            @{
                Id          = 'gaming-capture-off'   # trailing comment
                Name        = 'Doesn''t record'
                AkariOS     = $true
                Guided      = $false
                Default     = $null
                Registry    = @(
                    @{ Path = 'HKCU:\Software\X'; Name = 'A'; Type = 'DWord'; Value = 0; Default = $null }
                    @{ Path = 'HKCU:\Software\X'; Name = 'B'; Type = 'QWord'; Value = [uint64]72000000000; Default = 1 }
                )
            }
            """);
        Assert.Equal("gaming-capture-off", t["Id"]);
        Assert.Equal("Doesn't record", t["Name"]);
        Assert.Equal(true, t["AkariOS"]);
        Assert.Equal(false, t["Guided"]);
        Assert.Null(t["Default"]);
        var rows = Assert.IsType<object?[]>(t["Registry"]);
        Assert.Equal(2, rows.Length);
        var b = Assert.IsType<PsHashtable>(rows[1]);
        Assert.Equal(72000000000UL, b["Value"]);
        Assert.Equal(1, b["Default"]);
        Assert.Equal(["Id", "Name", "AkariOS", "Guided", "Default", "Registry"], t.Keys);
    }

    [Fact]
    public void Keys_are_case_insensitive_and_duplicates_fail()
    {
        Assert.Equal("x", Table("@{ Name = 'x' }")["name"]);
        var e = Assert.Throws<PsDataException>(() => PsData.Parse("@{\n  Name = 'x'\n  name = 'y'\n}"));
        Assert.Equal(3, e.Line);
        Assert.Contains("duplicate key", e.Message);
    }

    [Theory]
    [InlineData("1", 1)]
    [InlineData("-5", -5)]
    [InlineData("0x26", 0x26)]
    [InlineData("0xFFFFFFFF", -1)]
    [InlineData("0x80000000", int.MinValue)]
    public void Ints_read_as_PowerShell_5_reads_them(string text, int expected) =>
        Assert.Equal(expected, PsData.ParseValue(text));

    [Fact]
    public void Bigger_numbers_become_long_or_double()
    {
        Assert.Equal(4294967296L, PsData.ParseValue("4294967296"));
        Assert.Equal(0x100000000L, PsData.ParseValue("0x100000000"));
        Assert.Equal(-1L, PsData.ParseValue("0xFFFFFFFFFFFFFFFF"));
        Assert.Equal(1.5, PsData.ParseValue("1.5"));
        Assert.Equal(5L, PsData.ParseValue("5L"));
    }

    [Fact]
    public void Byte_arrays_and_comma_lists()
    {
        var t = Table("@{ B = [byte[]](0x01, 0xff,\n  2); L = 'a', 'b'; One = @('x'); None = @() }");
        Assert.Equal(new byte[] { 1, 255, 2 }, t["B"]);
        Assert.Equal(new object?[] { "a", "b" }, t["L"]);
        Assert.Equal(new object?[] { "x" }, t["One"]);
        Assert.Empty(Assert.IsType<object?[]>(t["None"]));
        Assert.Throws<PsDataException>(() => PsData.Parse("@{ B = [byte[]](256) }"));
    }

    [Fact]
    public void Array_subexpressions_flatten_each_line()
    {
        var a = Assert.IsType<object?[]>(PsData.ParseValue("@(\n 'a', 'b'\n 'c'; 'd'\n)"));
        Assert.Equal(new object?[] { "a", "b", "c", "d" }, a);
    }

    [Fact]
    public void Double_quoted_strings_take_escapes_and_known_variables()
    {
        var f = PsData.Parse("$k = 'HKLM:\\SOFTWARE\\Classes'\n$n = 3\n@{ A = \"$k\\x\"; B = \"tab`there\"; C = \"say \"\"hi\"\"\"; D = \"${n}x\"; E = \"cost $ 5\"; P = $k }");
        var t = Assert.IsType<PsHashtable>(f.Value);
        Assert.Equal("HKLM:\\SOFTWARE\\Classes\\x", t["A"]);
        Assert.Equal("tab\there", t["B"]);
        Assert.Equal("say \"hi\"", t["C"]);
        Assert.Equal("3x", t["D"]);
        Assert.Equal("cost $ 5", t["E"]);
        Assert.Equal("HKLM:\\SOFTWARE\\Classes", t["P"]);
        Assert.Equal("HKLM:\\SOFTWARE\\Classes", f.Variables["k"]);
        Assert.False(f.HasCode);
    }

    [Theory]
    [InlineData("@{ A = \"$env:SystemRoot\\x\" }")]
    [InlineData("@{ A = \"$unknown\\x\" }")]
    [InlineData("@{ A = \"$(Get-Date)\" }")]
    [InlineData("@{ A = $unknown }")]
    [InlineData("@{ A = Get-Something -Name 'x' }")]
    [InlineData("@{ A = @('a', 'b') -join ';' }")]
    [InlineData("@{ A = (Get-Item 'x').Name }")]
    [InlineData("@{ A = 'x'.Length }")]
    [InlineData("@{ A = @{ $x = 1 } }")]
    [InlineData("@{ A = foreach ($p in 'a', 'b') {\n    @{ Path = \"$c\\$p\" }\n  }\n}")]
    public void Anything_else_is_code(string text)
    {
        var t = Table(text);
        Assert.IsType<PsCode>(t["A"]);
        Assert.True(PsData.HasCode(t));
    }

    [Fact]
    public void A_foreach_in_a_list_is_one_code_item()
    {
        var a = Assert.IsType<object?[]>(Table("@{ A = @(\n @{ X = 1 }\n foreach ($p in 'a') {\n  @{ Path = \"$c\\$p\" }\n }\n @{ X = 2 }\n) }")["A"]);
        Assert.Equal(3, a.Length);
        Assert.IsType<PsCode>(a[1]);
        Assert.StartsWith("foreach", ((PsCode)a[1]!).Text);
    }

    [Fact]
    public void Script_blocks_keep_their_text()
    {
        var t = Table("""
            @{
                Detect = { -not (Get-MMAgent).MemoryCompression }
                Apply  = {
                    $s = '}' + "{" + @'
            } here {
            '@
                    # a } in a comment
                    <# and { here #>
                    if ($x) { "$(if ($y) { '}' })" }
                }
                After = 1
            }
            """);
        Assert.Equal(" -not (Get-MMAgent).MemoryCompression ", Assert.IsType<PsScriptBlock>(t["Detect"]).Text);
        Assert.Contains("# a } in a comment", Assert.IsType<PsScriptBlock>(t["Apply"]).Text);
        Assert.Equal(1, t["After"]);
    }

    [Fact]
    public void Data_list_groups_name_their_file()
    {
        var t = Table("@{ Entries = (Import-PowerShellDataFile \"$PSScriptRoot\\Appx.psd1\").Apps }");
        var i = Assert.IsType<PsImport>(t["Entries"]);
        Assert.Equal(("Appx.psd1", "Apps"), (i.File, i.Key));
        Assert.False(PsData.HasCode(t));
    }

    [Fact]
    public void Here_strings_read_as_written()
    {
        var t = Table("@{ A = @'\r\nline 1\r\n'quoted' $x\r\n'@\r\n B = 2 }");
        Assert.Equal("line 1\r\n'quoted' $x", t["A"]);
        Assert.Equal(2, t["B"]);
    }

    [Fact]
    public void A_choice_with_a_per_os_default()
    {
        var t = Table("@{ Default = @{ Win10 = 1; Win11 = 0 }; Choices = @(\n @{ Value = 0x26; Label = '0x26 short' }\n @{ Value = 0x18; Label = 'long'; Risk = 'Caution' }\n) }");
        var d = Assert.IsType<PsHashtable>(t["Default"]);
        Assert.Equal(0, d["win11"]);
        Assert.Equal(2, Assert.IsType<object?[]>(t["Choices"]).Length);
    }

    [Theory]
    [InlineData("@{ A = 'never closed }", 1)]
    [InlineData("@{\n A = 1\n", 1)]
    [InlineData("@{ A = 1 }\n@{ B = 2 }", 2)]
    [InlineData("$k = 'x'", 1)]
    public void Broken_text_says_where(string text, int line)
    {
        var e = Assert.Throws<PsDataException>(() => PsData.Parse(text));
        Assert.Equal(line, e.Line);
    }

    [Fact]
    public void A_command_at_the_top_is_code_but_not_the_value()
    {
        var f = PsData.Parse(". \"$PSScriptRoot\\Files\\x.ps1\"\n@{ Id = 'a' }");
        Assert.True(f.HasTopLevelCode);
        Assert.True(f.HasCode);
        Assert.Equal("a", Assert.IsType<PsHashtable>(f.Value)["Id"]);
    }

    [Fact]
    public void A_bom_is_skipped() => Assert.Equal(1, PsData.ParseValue("﻿1"));
}
