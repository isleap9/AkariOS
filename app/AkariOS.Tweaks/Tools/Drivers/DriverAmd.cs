using System.Text.RegularExpressions;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Drivers;

/// <summary>src/Tweaks/Tools/Drivers/DriverAmd.ps1: AMD's Adrenalin web setup, its link read off AMD's driver page (which
/// serves its links to browsers only), downloaded and started. An Action: a driver install, done by AMD's own installer.</summary>
[TweakCode("tools-driver-amd")]
public sealed partial class DriverAmd : ITweakCode
{
    public const string Page = "https://www.amd.com/en/support/download/drivers.html";

    public static readonly IReadOnlyDictionary<string, string> Browser = new Dictionary<string, string>
    {
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
        ["Accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        ["Referer"] = "https://www.amd.com/",
    };

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var http = TweakServices.Need(c.Services.Http, "downloader");
        var link = Links(http.Text(Page, Browser)).FirstOrDefault(SetupLink().IsMatch)
            ?? throw new InvalidOperationException("AMD's driver page has no Adrenalin setup link (the page changed?)");
        var exe = DriverSteps.Temp(c, "amddriver.exe");
        http.Download(link, exe, Browser);
        ShellStart.Run(c, exe);
    }

    /// <summary>The href of each &lt;a&gt; tag, in page order (Invoke-WebRequest -UseBasicParsing's Links).</summary>
    public static IEnumerable<string> Links(string html) => AnchorHref().Matches(html).Select(m => m.Groups[2].Value);

    [GeneratedRegex(@"<a\s[^>]*?href\s*=\s*(['""])(.*?)\1", RegexOptions.IgnoreCase | RegexOptions.Singleline)]
    private static partial Regex AnchorHref();

    // the block's -match: case-insensitive
    [GeneratedRegex(@"drivers\.amd\.com/drivers/installer/.*/whql/amd-software-adrenalin-edition-.*-minimalsetup-.*_web\.exe", RegexOptions.IgnoreCase)]
    private static partial Regex SetupLink();
}
