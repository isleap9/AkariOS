using System.Text.RegularExpressions;
using AkariOS.Core;

namespace AkariOS.Core.Tests;

public class ScaffoldTests
{
    [Fact]
    public void Version_is_the_PowerShell_apps()
    {
        var ps = File.ReadAllText(Path.Combine(Repo.Src, "Core", "Version.ps1"));
        var expected = Regex.Match(ps, "AkariVersion = '([^']+)'").Groups[1].Value;
        Assert.Equal(expected, AkariInfo.Version);
    }

    [Fact]
    public void Every_one_file_tweak_is_embedded_and_no_legacy_file()
    {
        var tweaks = Path.Combine(Repo.Src, "Tweaks");
        var onDisk = Directory.GetDirectories(tweaks)
            .SelectMany(d => Directory.GetFiles(d, "*", SearchOption.AllDirectories))
            .Select(f => "src/Tweaks/" + Path.GetRelativePath(tweaks, f).Replace('\\', '/'))
            .Order(StringComparer.Ordinal).ToList();
        var embedded = AkariInfo.EmbeddedPaths().Where(p => p.StartsWith("src/Tweaks/", StringComparison.Ordinal)).ToList();

        Assert.NotEmpty(onDisk);
        Assert.Equal(onDisk, embedded);
        Assert.DoesNotContain("src/Tweaks/Ported.psd1", embedded);
        Assert.DoesNotContain("src/Tweaks/Windows.ps1", embedded);
    }

    [Theory]
    [InlineData("src/Presets/AkariOS.json")]
    [InlineData("src/OneClick/reg.reg")]
    [InlineData("src/Core/Iso/Wizard/Modes/Minimal.psd1")]
    [InlineData("src/Core/Iso/LICENSE-zISOTweaker.txt")]
    [InlineData("src/UI/About.psd1")]
    [InlineData("src/UI/Unattend.psd1")]
    public void Shared_data_is_embedded(string path) => Assert.Contains(path, AkariInfo.EmbeddedPaths());
}
