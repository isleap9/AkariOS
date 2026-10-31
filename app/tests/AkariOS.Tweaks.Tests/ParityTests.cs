using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tests;

/// <summary>
/// app/parity.txt = what each app has that the other lacks (ADR 0007). It fails when the file is out of date; with
/// AKARI_UPDATE_PARITY=1 it writes the file instead (commit it with the change that moved it).
/// </summary>
public class ParityTests
{
    private static string Root()
    {
        for (var d = new DirectoryInfo(AppContext.BaseDirectory); d != null; d = d.Parent)
            if (File.Exists(Path.Combine(d.FullName, "AGENTS.md")) && Directory.Exists(Path.Combine(d.FullName, "src"))) return d.FullName;
        throw new DirectoryNotFoundException("The repo root was not found");
    }

    [Fact]
    public void Parity_txt_is_up_to_date()
    {
        var root = Root();
        var loaded = new Loader(new FolderSourceFiles(root), TweaksAssembly.Codes).Load();
        var text = Parity.Text(Parity.Of(loaded, TweaksAssembly.Codes));
        var file = Path.Combine(root, "app", "parity.txt");
        if (Environment.GetEnvironmentVariable("AKARI_UPDATE_PARITY") == "1")
        {
            File.WriteAllText(file, text);
            return;
        }
        var current = File.Exists(file) ? File.ReadAllText(file).Replace("\r\n", "\n") : "";
        Assert.True(current == text, "app/parity.txt is out of date: run the tests once with AKARI_UPDATE_PARITY=1 and commit it");
    }

    [Fact]
    public void Every_class_is_for_a_tweak_that_needs_code()
    {
        var loaded = new Loader(new FolderSourceFiles(Root()), TweaksAssembly.Codes).Load();
        Assert.DoesNotContain(loaded.Problems, p => p.Message.Contains("has a C# class"));
        Assert.Empty(Parity.Of(loaded, TweaksAssembly.Codes).NativeOnly);
    }
}
