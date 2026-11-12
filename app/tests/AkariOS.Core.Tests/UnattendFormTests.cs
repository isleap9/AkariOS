using AkariOS.Core.Sources;
using AkariOS.Core.Unattend;

namespace AkariOS.Core.Tests;

/// <summary>
/// The Unattend Generator's form (UI\UnattendForm.ps1 as a model): built from src/UI/Unattend.psd1, read back as his
/// fields (only the picked branches), filled from fields; his site's files open and come out the same again.
/// </summary>
public sealed class UnattendFormTests
{
    private static readonly ISourceFiles Files = new EmbeddedSourceFiles();
    private static readonly PcRegion Italian = new("it-IT", "it-IT", "00000410", "118", "W. Europe Standard Time");
    private static string Fixture(string name) => File.ReadAllText(Path.Combine(Repo.Root, "tests", "Fixtures", "Unattend", name + ".xml"));

    private static (UnattendForm Form, Dictionary<string, string[]> Start) Started()
    {
        var form = UnattendForm.Build(Files);
        var start = UnattendStart.Fields(Files, Italian);
        form.Set(start);
        return (form, start);
    }

    private static FormBinding Binding(UnattendForm form, string field) => form.Bindings.First(b => b.Field == field);

    [Fact]
    public void It_has_his_sections_in_his_order()
    {
        var form = UnattendForm.Build(Files);
        Assert.Equal("Region and language", form.Sections[0].Title);
        Assert.Equal("XML markup for more components", form.Sections[^1].Title);
        Assert.True(form.Bindings.Count > 100);
    }

    [Fact]
    public void It_starts_from_the_defaults_and_this_PC_and_leaves_hidden_branches_out()
    {
        var (form, _) = Started();
        var f = form.Fields();
        Assert.Equal("Unattended|it-IT|00000410|W. Europe Standard Time|Admin|Default",
            string.Join("|", f.Get("LanguageMode"), f.Get("UILanguage"), f.Get("Keyboard"), f.Get("TimeZone"), f.Get("AccountName0"), f.Get("PEMode")));
        Assert.False(f.ContainsKey("PartitionMode"));
        Assert.False(f.ContainsKey("Locale2"));
        Assert.False(f.ContainsKey("PEScript"));
        Assert.StartsWith("SELECT DISK=0", Binding(form, "DiskpartScript").Value);
        Assert.Equal(2, form.Accounts.Shown);
    }

    [Fact]
    public void A_picked_branch_counts_its_fields_and_unpicking_it_leaves_them_out()
    {
        var (form, _) = Started();
        var pe = Binding(form, "PEMode");
        pe.Pick("Generated");
        Assert.Equal("Unattended", form.Fields().Get("PartitionMode"));
        Assert.True(form.Wipes());
        pe.Pick("Default");
        Assert.False(form.Fields().ContainsKey("PartitionMode"));
        Assert.False(form.Wipes());
    }

    [Fact]
    public void A_gate_tells_whether_its_branch_shows()
    {
        var (form, _) = Started();
        var partition = Binding(form, "PartitionMode");
        Assert.False(partition.Counts);
        Binding(form, "PEMode").Pick("Generated");
        Assert.True(partition.Counts);
    }

    public static TheoryData<string> FixtureNames() => [.. UnattendOracleTests.FixtureNames];

    [Theory, MemberData(nameof(FixtureNames))]
    public void A_file_from_his_site_opens_and_saves_the_very_same_file(string name)
    {
        var (form, start) = Started();
        var theirs = Fixture(name);
        form.Open(UnattendQuery.FromXml(theirs)!, start);
        var ours = System.Text.Encoding.ASCII.GetString(UnattendFile.Make(form.Fields()));
        Assert.Equal(UnattendOracleTests.Canonical(theirs), UnattendOracleTests.Canonical(ours));
    }

    [Fact]
    public void Opening_a_file_fills_the_form_Wi_Fi_the_third_language_both_accounts_and_an_empty_row()
    {
        var (form, start) = Started();
        form.Open(UnattendQuery.FromXml(Fixture("2-unattended"))!, start);
        Assert.Equal("Home & Co", Binding(form, "WifiName").Value);
        Assert.True(Binding(form, "UseKeyboard3").On);
        Assert.Equal(3, form.Accounts.Shown);
    }

    [Fact]
    public void A_dropdown_value_its_list_lacks_is_added_first()
    {
        var (form, _) = Started();
        form.Set(new Dictionary<string, string[]> { ["Keyboard"] = ["0000abcd"] });
        var kb = Binding(form, "Keyboard");
        Assert.Equal(("0000abcd", "0000abcd"), (kb.Choices[0].Id, kb.Choices[0].Name));
        Assert.Equal("0000abcd", kb.Value);
    }

    [Fact]
    public void Rows_grow_one_at_a_time_and_show_the_used_ones_and_one_empty()
    {
        var (form, _) = Started();
        var system = form.Scripts.First(s => s.Phase == "System").Rows;
        Assert.Equal(1, system.Shown);
        system.Add();
        Assert.Equal(2, system.Shown);
        form.Set(new Dictionary<string, string[]> { ["SystemScript3"] = ["echo hi"] });
        Assert.Equal(5, system.Shown);
        Assert.Equal(1, form.Components.Shown);
    }

    [Fact]
    public void A_changed_binding_says_so()
    {
        var (form, _) = Started();
        var wifi = Binding(form, "WifiMode");
        var name = Binding(form, "WifiName");
        var told = 0;
        wifi.Changed += () => told++;
        wifi.Pick("Unattended");
        wifi.Pick("Unattended");
        Assert.True(name.Counts);
        Assert.Equal(1, told);
    }
}
