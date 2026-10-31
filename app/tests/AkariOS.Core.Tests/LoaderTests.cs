using AkariOS.Core.Data;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests;

public class LoaderTests
{
    private static readonly IReadOnlyDictionary<string, ITweakCode> NoCode = new Dictionary<string, ITweakCode>();

    private const string Toggle = """
        @{
            Id          = 'gaming-dvr-off'
            Name        = 'Game DVR off'
            Section     = 'Optimize'
            Category    = 'Gaming'
            Risk        = 'Safe'
            AkariOS     = $true
            Requires    = 'Win11'
            Description = 'No background recording.'
            Registry    = @(
                @{ Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_Enabled'; Type = 'DWord'; Value = 0; Default = @{ Win10 = 1; Win11 = 0 } }
                @{ Path = 'HKCU:\Software\Akari\Key'; Value = 'Key'; Default = $null }
            )
        }
        """;

    private static LoadResult Load(MemorySourceFiles files, IReadOnlyDictionary<string, ITweakCode>? codes = null) =>
        new Loader(files, codes ?? NoCode).Load();

    private static MemorySourceFiles One(string path, string text) => new MemorySourceFiles().Add(path, text);

    private static string Message(string text, string path = "src/Tweaks/Optimize/Gaming/T.ps1")
    {
        var r = Load(One(path, text));
        Assert.Empty(r.Tweaks);
        return Assert.Single(r.Problems).Message;
    }

    [Fact]
    public void Reads_a_registry_toggle()
    {
        var r = Load(One("src/Tweaks/Optimize/Gaming/GameDvr.ps1", Toggle));
        Assert.Empty(r.Problems);
        var t = Assert.Single(r.Tweaks);
        Assert.Equal(("gaming-dvr-off", TweakKind.Toggle, Risk.Safe, "Run"), (t.Id, t.Kind, t.Risk, t.Button));
        Assert.True(t.AkariOS);
        Assert.True(t.Guided);
        Assert.Equal(["Win11"], t.Requires);
        Assert.Equal(2, t.Registry!.Count);
        Assert.Equal(new OsValue(1, 0), t.Registry[0].Default);
        Assert.Equal(0, t.Registry[0].Default.For(26100));
        Assert.True(t.Registry[1].IsKeyRow);
        Assert.False(t.NeedsCode);
        Assert.True(t.Native);
        Assert.Equal("src/Tweaks/Optimize/Gaming/GameDvr.ps1", t.Source);
    }

    [Fact]
    public void Only_section_category_files_are_tweaks()
    {
        var r = Load(new MemorySourceFiles()
            .Add("src/Tweaks/Windows.ps1", "Add-Tweak -Id 'legacy'")
            .Add("src/Tweaks/Ported.psd1", "@{}")
            .Add("src/Tweaks/Optimize/Gaming/Files/Helper.ps1", "function Get-X { }")
            .Add("src/Tweaks/Optimize/Gaming/Files/rows.psd1", "@{ Rows = @() }")
            .Add("src/Tweaks/Optimize/Gaming/GameDvr.ps1", Toggle));
        Assert.Empty(r.Problems);
        Assert.Equal(["gaming-dvr-off"], r.Tweaks.Select(t => t.Id));
    }

    public static TheoryData<string, string> Broken => new()
    {
        { Toggle.Replace("Name        = 'Game DVR off'", ""), "missing Name" },
        { Toggle.Replace("'gaming-dvr-off'", "'Gaming_DVR'"), "must be kebab-case" },
        { Toggle.Replace("Risk        = 'Safe'", "Risk = '1'"), "Risk must be Safe, Caution or Advanced" },
        { Toggle.Replace("Category    = 'Gaming'", "Category = 'Power'"), "must match the folder 'Optimize/Gaming'" },
        { Toggle.Replace("Requires    = 'Win11'", "Requires = 'Win12'"), "Requires 'Win12' is not one of" },
        { Toggle.Replace("Risk        = 'Safe'", "Risk = 'Safe'; Kind = 'Switch'"), "Kind must be Toggle, Choice, Action or Group" },
        { Toggle.Replace("; Default = @{ Win10 = 1; Win11 = 0 }", ""), "is missing Default" },
        { Toggle.Replace("Value = 'Key'; Default = $null", "Value = 'Yes'; Default = $null"), "must be 'Key' or $null" },
        { Toggle.Replace("Value = 'Key'; Default = $null", "Value = $null; Default = $null"), "are both $null" },
        { Toggle.Replace("Type = 'DWord'; ", ""), "Registry entry is missing Type" },
        { Toggle.Replace("Registry    = @(", "Detect = { $true }; Registry2 = @("), "a Toggle needs Registry, or both Apply and Revert" },
        { Toggle.Replace("AkariOS     = $true", "Prepare = { 1 }"), "Prepare is only for a SafeMode Tweak" },
        { Toggle.Replace("AkariOS     = $true", "Value = { 1 }"), "Value is only for a Choice" },
    };

    [Theory]
    [MemberData(nameof(Broken))]
    public void Files_that_break_a_rule_are_problems(string text, string message) =>
        Assert.Contains(message, Message(text));

    private const string Choice = """
        @{
            Id = 'priority'; Name = 'Priority'; Section = 'Advanced'; Category = 'Tuning'; Kind = 'Choice'; Risk = 'Safe'
            Description = 'x'
            Registry    = @{ Path = 'HKLM:\SYSTEM\X'; Name = 'Win32PrioritySeparation'; Type = 'DWord' }
            Choices     = @(
                @{ Value = 0x26; Label = '0x26 short' }
                @{ Value = 0x18; Label = '0x18 long'; Risk = 'Caution' }
            )
            Recommended = 0x26
            Default     = 2
        }
        """;

    [Fact]
    public void Reads_a_choice()
    {
        var t = Assert.Single(Load(One("src/Tweaks/Advanced/Tuning/P.ps1", Choice)).Tweaks);
        Assert.Equal(TweakKind.Choice, t.Kind);
        Assert.Equal(2, t.Choices.Count);
        Assert.Equal(Risk.Caution, t.Choices[1].Risk);
        Assert.Equal(0x26, t.Recommended);
        Assert.Equal(2, t.Default);
        Assert.Single(t.Registry!);
    }

    [Theory]
    [InlineData("Recommended = 0x26", "Recommended = 0x99", "Recommended must be one of the Choices")]
    [InlineData("Default     = 2", "", "a Choice needs Default")]
    [InlineData("Registry    = @{ Path = 'HKLM:\\SYSTEM\\X'; Name = 'Win32PrioritySeparation'; Type = 'DWord' }", "", "a Choice needs exactly one Registry entry")]
    public void Choice_rules(string from, string to, string message) =>
        Assert.Contains(message, Message(Choice.Replace(from, to), "src/Tweaks/Advanced/Tuning/P.ps1"));

    private const string Action = """
        # Action: an installed app is removed with its own uninstaller.
        @{
            Id = 'install-7-zip'; Name = '7-Zip'; Section = 'Apps'; Category = 'Install'; Kind = 'Action'; Button = 'Install'
            Risk = 'Safe'; Description = 'x'; Winget = '7zip.7zip'
        }
        """;

    [Fact]
    public void Reads_a_winget_action()
    {
        var t = Assert.Single(Load(One("src/Tweaks/Apps/Install/7Zip.ps1", Action)).Tweaks);
        Assert.Equal((TweakKind.Action, "Install"), (t.Kind, t.Button));
        Assert.Equal(["7zip.7zip"], t.Winget);
        Assert.False(t.NeedsCode);
    }

    [Theory]
    [InlineData("# Action: an installed app is removed with its own uninstaller.", "# an app", "needs a '# Action:")]
    [InlineData("Winget = '7zip.7zip'", "Winget = '7zip.7zip'; Apply = { 1 }", "gets its Apply from the engine")]
    [InlineData("Winget = '7zip.7zip'", "Winget = '7zip 7zip'", "is not a package id")]
    [InlineData("Winget = '7zip.7zip'", "Winget = '7zip.7zip'; WingetSource = 'store'", "WingetSource must be winget or msstore")]
    [InlineData("Winget = '7zip.7zip'", "After = { 1 }", "Before and After are only for an Action with Winget")]
    [InlineData("Winget = '7zip.7zip'", "Note = 1", "an Action needs Apply")]
    [InlineData("Winget = '7zip.7zip'", "Apply = { Read-Host 'name' }", "Apply uses Read-Host")]
    public void Action_rules(string from, string to, string message) =>
        Assert.Contains(message, Message(Action.Replace(from, to), "src/Tweaks/Apps/Install/7Zip.ps1"));

    [Fact]
    public void Script_blocks_need_code_and_take_its_class()
    {
        var file = Toggle.Replace("Registry    = @(", "Detect = { (Get-MMAgent).MemoryCompression }\n    Registry    = @(");
        var code = new FakeCode();
        var t = Assert.Single(Load(One("src/Tweaks/Optimize/Gaming/GameDvr.ps1", file), new Dictionary<string, ITweakCode> { ["gaming-dvr-off"] = code }).Tweaks);
        Assert.True(t.NeedsCode);
        Assert.Same(code, t.Code);
        Assert.True(t.Has("Detect"));
        Assert.True(t.Native);

        var without = Assert.Single(Load(One("src/Tweaks/Optimize/Gaming/GameDvr.ps1", file)).Tweaks);
        Assert.False(without.Native);
    }

    [Fact]
    public void A_class_for_a_data_only_file_is_a_problem()
    {
        var r = Load(One("src/Tweaks/Optimize/Gaming/GameDvr.ps1", Toggle), new Dictionary<string, ITweakCode> { ["gaming-dvr-off"] = new FakeCode() });
        Assert.Contains("its file is data only", Assert.Single(r.Problems).Message);
        Assert.Null(Assert.Single(r.Tweaks).Code);
    }

    [Fact]
    public void Ids_are_unique()
    {
        var r = Load(new MemorySourceFiles().Add("src/Tweaks/Optimize/Gaming/A.ps1", Toggle)
            .Add("src/Tweaks/Optimize/Gaming/B.ps1", Toggle.Replace("GameDVR_Enabled", "Other").Replace("Software\\Akari\\Key", "Software\\Akari\\Key2")));
        Assert.Single(r.Tweaks);
        Assert.Contains("already used by src/Tweaks/Optimize/Gaming/A.ps1", Assert.Single(r.Problems).Message);
    }

    [Theory]
    [InlineData(@"@{ Path = 'HKCU:\System\GameConfigStore'; Name = 'gamedvr_enabled'; Type = 'DWord'; Value = 1; Default = $null }")]
    [InlineData(@"@{ Path = 'HKCU:\Software\Akari\Key\Inside'; Name = 'X'; Type = 'DWord'; Value = 1; Default = $null }")]
    [InlineData(@"@{ Path = 'HKEY_CURRENT_USER\System'; Value = 'Key'; Default = $null }")]
    public void One_owner_per_registry_value(string row)
    {
        var other = $$"""
            @{ Id = 'other'; Name = 'O'; Section = 'Optimize'; Category = 'Gaming'; Risk = 'Safe'; Description = 'x'
               Registry = @( {{row}} ) }
            """;
        var r = Load(new MemorySourceFiles().Add("src/Tweaks/Optimize/Gaming/A.ps1", Toggle).Add("src/Tweaks/Optimize/Gaming/B.ps1", other));
        Assert.Equal(["gaming-dvr-off"], r.Tweaks.Select(t => t.Id));
        Assert.Contains("already owned by 'gaming-dvr-off'", Assert.Single(r.Problems).Message);
    }

    [Fact]
    public void A_toggle_with_code_and_no_detect_is_a_warning()
    {
        var file = Toggle.Replace("Registry    = @(", "Apply = { 1 }; Revert = { 2 }; Rows = @(");
        var r = Load(One("src/Tweaks/Optimize/Gaming/T.ps1", file));
        Assert.Single(r.Tweaks);
        Assert.Equal("Warning", Assert.Single(r.Problems).Level);
    }

    // ---- Groups

    private static MemorySourceFiles AppxGroup(string rows = "") => new MemorySourceFiles()
        .Add("src/Tweaks/Apps/Remove/Appx.ps1", """
            # Action: a removed app only comes back from the Store.
            @{
                Id = 'appx'; Kind = 'Group'; Name = 'Remove apps'; Section = 'Apps'; Category = 'Remove'; Risk = 'Caution'
                Description = 'x'; EntryKind = 'AppxRemove'; KeepNames = 'Microsoft.Windows*'
                Entries = (Import-PowerShellDataFile "$PSScriptRoot\Appx.psd1").Apps
            }
            """)
        .Add("src/Tweaks/Apps/Remove/Appx.psd1", $$"""
            @{ Apps = @(
                @{ Name = 'Microsoft.BingNews'; Display = 'News'; Risk = 'Safe' }
                @{ Name = 'Microsoft.WindowsCalculator'; Display = 'Calculator' }
                @{ Name = 'Microsoft.Xbox*'; Display = 'Xbox'; Keep = $true }
                {{rows}}
            ) }
            """);

    [Fact]
    public void A_rows_group_loads_its_entries()
    {
        var r = Load(AppxGroup());
        Assert.Empty(r.Problems);
        var g = Assert.Single(r.Groups);
        Assert.Equal((EntryKind.AppxRemove, 3), (g.EntryKind, g.Rows.Count));
        var news = r.Find("appx/Microsoft.BingNews")!;
        Assert.Equal(("News", TweakKind.Action, "Remove", Risk.Safe, false, "appx", "Microsoft.BingNews"), (news.Name, news.Kind, news.Button, news.Risk, news.Keep, news.Group, news.Package));
        var calc = r.Find("appx/Microsoft.WindowsCalculator")!;
        Assert.Equal((true, Risk.Advanced), (calc.Keep, calc.Risk));
    }

    [Fact]
    public void An_entry_from_the_pc_takes_its_row_by_wildcard()
    {
        var g = Load(AppxGroup()).Groups[0];
        var x = Loader.ResolveEntry([g], "appx/Microsoft.XboxGamingOverlay")!;
        Assert.Equal(("Xbox", true, Risk.Advanced), (x.Name, x.Keep, x.Risk));
        var unknown = Loader.ResolveEntry([g], "appx/Contoso.App")!;
        Assert.Equal(("Contoso.App", false, Risk.Caution), (unknown.Name, unknown.Keep, unknown.Risk));
        Assert.Null(Loader.ResolveEntry([g], "appx/"));
        Assert.Null(Loader.ResolveEntry([g], "feature/X"));
    }

    [Fact]
    public void A_capability_matches_its_row_without_the_version()
    {
        var g = new TweakGroup
        {
            Id = "capability", Name = "C", Section = "Apps", Category = "Remove", EntryKind = EntryKind.CapabilityRemove, Source = "x",
            Rows = [PsHashtable.Of(("Name", "App.StepsRecorder"), ("Display", "Steps Recorder"))],
        };
        Assert.Equal("Steps Recorder", Loader.ResolveEntry([g], "capability/App.StepsRecorder~~~~0.0.1.0")!.Name);
        Assert.True(Loader.ResolveEntry([g], "capability/App.StepsRecorder~~~~0.0.1.0")!.Reboot);
    }

    [Theory]
    [InlineData("@{ Display = 'No name' }", "every Entry needs a Name")]
    [InlineData("@{ Name = 'X'; Risk = 'Low' }", "Risk must be Safe, Caution or Advanced")]
    public void Group_rules(string row, string message) => Assert.Contains(message, Assert.Single(Load(AppxGroup(row)).Problems).Message);

    [Fact]
    public void A_group_needs_a_known_kind() =>
        Assert.Contains("a Group needs an EntryKind", Assert.Single(Load(AppxGroup().Add("src/Tweaks/Apps/Remove/Appx.ps1",
            "@{ Id = 'appx'; Kind = 'Group'; Name = 'R'; Section = 'Apps'; Category = 'Remove'; Risk = 'Safe'; Description = 'x'; EntryKind = 'Nope'; Entries = @(@{ Name = 'a' }) }")).Problems).Message);

    [Fact]
    public void The_embedded_files_are_the_repo_files()
    {
        var embedded = new EmbeddedSourceFiles().List("src/Tweaks/");
        var folder = new FolderSourceFiles(Repo.Root).List("src/Tweaks/").Where(p => p.Split('/').Length > 3).ToList();
        Assert.Equal(folder, embedded);
        Assert.Equal(new FolderSourceFiles(Repo.Root).ReadBytes(embedded[0]), new EmbeddedSourceFiles().ReadBytes(embedded[0]));
    }

    private sealed class FakeCode : ITweakCode;
}
