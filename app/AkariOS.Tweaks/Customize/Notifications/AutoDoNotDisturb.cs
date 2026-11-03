using System.Text.RegularExpressions;
using AkariOS.Core.Data;
using AkariOS.Core.Registry;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Notifications;

/// <summary>src/Tweaks/Customize/Notifications/AutoDoNotDisturb.ps1: CloudStore blobs from Files/do-not-disturb.psd1 (read
/// from it). The automatic rules are written for the "default" prefix and each account's {guid}; Windows' cache of
/// them both ways but never read by Detect (Windows rewrites it); the focus theme written on Apply, its key deleted on
/// Revert.</summary>
[TweakCode("notifications-no-auto-dnd")]
public sealed partial class AutoDoNotDisturb : ITweakCode
{
    public const string Store = @"HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store";
    private const string Current = $@"{Store}\DefaultAccount\Current";

    [GeneratedRegex(@"^(\{[0-9a-fA-F-]+\})\$windows\.data\.donotdisturb\.quietmoment\$quietmomentlist$", RegexOptions.IgnoreCase)]
    private static partial Regex AccountList();

    /// <summary>The data file: (Key, Off, Default) for Rules and Cache, (Key, Off) for Focus.</summary>
    public sealed record Blob(string Key, byte[] Off, byte[]? Default);

    public static (IReadOnlyList<Blob> Rules, IReadOnlyList<Blob> Cache, Blob Focus) Data(Tweak t, TweakContext c)
    {
        var d = (PsHashtable)PsData.Parse(c.Files.ReadText($"{TweakContext.FolderOf(t)}/Files/do-not-disturb.psd1")).Value!;
        static Blob Of(object? o)
        {
            var h = (PsHashtable)o!;
            return new((string)h.Get("Key")!, Hex(h.Get("Off"))!, Hex(h.Get("Default")));
        }
        return (PsSemantics.AsList(d.Get("Rules")).Select(Of).ToList(), PsSemantics.AsList(d.Get("Cache")).Select(Of).ToList(), Of(d.Get("Focus")));
    }

    /// <summary>ConvertFrom-AkariHex: 'ab,01' text as bytes.</summary>
    public static byte[]? Hex(object? text) => text is string s ? Convert.FromHexString(s.Replace(",", "")) : null;

    /// <summary>"default" then each account's {guid} that has a quiet moment list.</summary>
    public static IReadOnlyList<string> Prefixes(TweakContext c) =>
        ["default", .. c.Registry.SubKeys(Current).Select(k => AccountList().Match(k)).Where(m => m.Success).Select(m => m.Groups[1].Value)];

    /// <summary>The rows Detect reads: every rule for every prefix, then the focus theme (Default: none).</summary>
    public static IReadOnlyList<RegistryRow> DetectRows(Tweak t, TweakContext c)
    {
        var (rules, _, focus) = Data(t, c);
        var rows = Prefixes(c).SelectMany(p => rules.Select(r => FileData.Row($@"{Current}\{p}${r.Key}", "Data", "Binary", r.Off, r.Default))).ToList();
        rows.Add(FileData.Row($@"{Store}\{focus.Key}", "Data", "Binary", focus.Off));
        return rows;
    }

    public TweakState Detect(Tweak tweak, TweakContext c) => c.Registry.State(DetectRows(tweak, c), c.System.Build);

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var (rules, cache, focus) = Data(tweak, c);
        foreach (var p in Prefixes(c)) foreach (var r in rules) c.Registry.SetValue($@"{Current}\{p}${r.Key}", "Data", r.Off, "Binary");
        foreach (var r in cache) c.Registry.SetValue($@"{Store}\{r.Key}", "Data", r.Off, "Binary");
        c.Registry.SetValue($@"{Store}\{focus.Key}", "Data", focus.Off, "Binary");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        var (rules, cache, focus) = Data(tweak, c);
        foreach (var p in Prefixes(c)) foreach (var r in rules) c.Registry.SetValue($@"{Current}\{p}${r.Key}", "Data", r.Default, "Binary");
        foreach (var r in cache) c.Registry.SetValue($@"{Store}\{r.Key}", "Data", r.Default, "Binary");
        // FR33THY's Default deletes the focus theme key
        c.Registry.DeleteKey($@"{Store}\{focus.Key}");
    }
}
