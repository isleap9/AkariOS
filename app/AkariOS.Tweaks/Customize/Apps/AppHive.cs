using System.Text.RegularExpressions;
using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Apps;

/// <summary>
/// What the Customize › Apps Tweaks on a Store app's own settings hive share (Import-AkariAppSettings,
/// Get-AkariAppSettingState). Everything is read out of the file's blocks, not copied: the package family and the Detect
/// rows (Detect), the .reg text written inline, the programs stopped, the pauses and the Settings page opened first, the
/// message when the hive won't open (Apply / Revert).
/// </summary>
public static partial class AppHive
{
    [GeneratedRegex(@"Get-AkariAppSettingState '([^']+)'")]
    private static partial Regex FamilyCall();

    [GeneratedRegex(@"@\{ Name = (?:'(?<n>[^']+)'|""(?<n>[^""]+)""); Value = (?<v>\d+); Default = (?<d>\d+) \}")]
    private static partial Regex DetectRow();

    [GeneratedRegex(@"foreach \(\$a in (?<l>'[^)]+')\)")]
    private static partial Regex DetectList();

    [GeneratedRegex(@"\[HKEY_LOCAL_MACHINE\\AkariAppHive\\(?<k>[^\]]+)\]")]
    private static partial Regex RegKey();

    [GeneratedRegex(@"(?:""""|`"")(?<n>[^""`]+)(?:""""|`"")=(?<d>hex\([0-9a-fA-F]+\):[0-9a-fA-F,]+|-)")]
    private static partial Regex RegValue();

    [GeneratedRegex(@"@\((?<l>'[^)]+')\)\s*\|\s*ForEach-Object")]
    private static partial Regex RegList();

    // in the block's order: a page opened, a pause, the programs stopped (a list piped to Stop-Process, or one by name)
    [GeneratedRegex(@"Start-Process '(?<open>[^']+)'|Start-Sleep -Seconds (?<sleep>\d+)|(?<list>'[\w.]+'(?:,\s*'[\w.]+')*)\s*\|\s*ForEach-Object\s*\{\s*Stop-Process|Stop-Process -Name (?<one>[\w.]+)")]
    private static partial Regex Step();

    [GeneratedRegex(@"throw '(?<m>(?:[^']|'')*)'")]
    private static partial Regex Refusal();

    [GeneratedRegex(@"if \(-not \(Test-Path -LiteralPath \$dat\)\) \{ (?:'(?<m>(?:[^']|'')*)'; )?return \}")]
    private static partial Regex NoFile();

    public static string Block(Tweak t, string name) =>
        (t.Fields.Get(name) as PsScriptBlock)?.Text ?? throw new InvalidOperationException($"{t.Source} has no {name} block");

    private static IReadOnlyList<string> List(string text) =>
        PsSemantics.AsList(PsData.ParseValue(text)).Select(v => PsSemantics.Text(v)!).ToList();

    private static string Unquote(string s) => s.Replace("''", "'");

    /// <summary>The app's package family (MicrosoftWindows.Client.CBS_cw5n1h2txyewy…).</summary>
    public static string Family(Tweak t) =>
        FamilyCall().Match(Block(t, "Detect")) is { Success: true } m ? m.Groups[1].Value : throw new InvalidOperationException($"{t.Source}: no app family");

    /// <summary>The Detect rows; a name with $a once per app of its foreach list.</summary>
    public static IReadOnlyList<AppSettingRow> Rows(Tweak t)
    {
        var detect = Block(t, "Detect");
        var apps = DetectList().Match(detect) is { Success: true } l ? List(l.Groups["l"].Value) : [];
        return DetectRow().Matches(detect).SelectMany(m =>
        {
            var (n, v, d) = (m.Groups["n"].Value, int.Parse(m.Groups["v"].Value), int.Parse(m.Groups["d"].Value));
            return n.Contains("$a", StringComparison.Ordinal) ? apps.Select(a => new AppSettingRow(n.Replace("$a", a), v, d)) : [new AppSettingRow(n, v, d)];
        }).ToList();
    }

    public static IAppSettings Settings(TweakContext c) => TweakServices.Need(c.Services.AppSettings, "app settings files");

    /// <summary>The real user's settings.dat of the app.</summary>
    public static string Dat(Tweak t, TweakContext c) => AppSettings.Dat(FileData.UserFolder(c, "Local AppData"), Family(t));

    public static TweakState State(Tweak t, TweakContext c) => AppSettings.State(Settings(c).Read(Dat(t, c)), Rows(t));

    /// <summary>The .reg text a block builds inline: one key, its values (a $_ value once per app of the piped list).</summary>
    public static string RegText(string block)
    {
        var key = RegKey().Match(block) is { Success: true } k ? k.Groups["k"].Value : throw new InvalidOperationException("the block has no .reg key");
        var apps = RegList().Match(block) is { Success: true } l ? List(l.Groups["l"].Value) : [];
        var lines = RegValue().Matches(block).SelectMany(m =>
        {
            var (n, d) = (m.Groups["n"].Value, m.Groups["d"].Value);
            return n == "$_" ? apps.Select(a => $"\"{a}\"={d}\r\n") : [$"\"{n}\"={d}\r\n"];
        });
        return $"Windows Registry Editor Version 5.00\r\n\r\n[{AppSettings.ImportRoot}\\{key}]\r\n" + string.Concat(lines);
    }

    /// <summary>The block's steps before the change: the page opened (a failure ignored), the pauses, the programs stopped.</summary>
    public static void Prepare(string block, TweakContext c)
    {
        foreach (Match m in Step().Matches(block))
        {
            if (m.Groups["open"].Success)
                try { TweakServices.Need(c.Services.Launcher, "Settings pages").Open(m.Groups["open"].Value); }
                catch (Exception e) when (e is not NotSupportedException) { }
            else if (m.Groups["sleep"].Success) c.Services.Sleep(TimeSpan.FromSeconds(int.Parse(m.Groups["sleep"].Value)));
            else
            {
                var names = m.Groups["list"].Success ? List(m.Groups["list"].Value) : [m.Groups["one"].Value];
                foreach (var n in names) TweakServices.Need(c.Services.Processes, "program stopping").Stop(n);
            }
        }
    }

    /// <summary>A block that writes the app's hive: its steps, then its .reg text (or the one given) imported. A block
    /// that checks for the settings file first stops there without one (saying its line, if any); the block's own
    /// message when the hive won't open.</summary>
    public static void Change(Tweak t, TweakContext c, string name, string? regText = null)
    {
        var block = Block(t, name);
        Prepare(block, c);
        var dat = Dat(t, c);
        if (NoFile().Match(block) is { Success: true } none && !File.Exists(dat))
        {
            if (none.Groups["m"].Success) c.Log.Write(Unquote(none.Groups["m"].Value));
            return;
        }
        if (!Settings(c).Import(dat, regText ?? RegText(block)))
            throw new InvalidOperationException(Refusal().Match(block) is { Success: true } r ? Unquote(r.Groups["m"].Value) : $"{Family(t)}'s settings could not be opened");
    }
}
