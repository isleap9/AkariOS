using System.Text.RegularExpressions;
using AkariOS.Core.Data;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Notifications;

/// <summary>src/Tweaks/Customize/Notifications/PriorityNotifications.ps1: each account's priority-only quiet hours profile
/// gets the Data value of Files/priority-notifications.txt (a .reg fragment, read with RegReader and written through
/// the registry engine where the PowerShell app imports it with reg.exe). An Action: the blob holds the account's own
/// list, so there is no single Default. No account settings yet = nothing to change.</summary>
[TweakCode("notifications-priority-list-empty")]
public sealed partial class PriorityNotifications : ITweakCode
{
    private const string Current = @"HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\Current";
    public const string Profile = @"windows.data.donotdisturb.quiethoursprofile$quiethoursprofilelist\windows.data.donotdisturb.quiethoursprofile$microsoft.quiethoursprofile.priorityonly";

    [GeneratedRegex(@"^\{[a-f0-9-]+\}\$", RegexOptions.IgnoreCase)]
    private static partial Regex Account();

    /// <summary>The accounts' {guid}s, each once, in the order the keys come.</summary>
    public static IReadOnlyList<string> Accounts(TweakContext c) =>
        c.Registry.SubKeys(Current).Where(k => Account().IsMatch(k)).Select(k => k.Split('$')[0]).Distinct(StringComparer.Ordinal).ToList();

    /// <summary>The file's values (its ';' lines left out, as the block leaves them).</summary>
    public static IReadOnlyList<RegFileValue> Values(Tweak t, TweakContext c)
    {
        var lines = c.Files.ReadText($"{TweakContext.FolderOf(t)}/Files/priority-notifications.txt")
            .Split(["\r\n", "\n"], StringSplitOptions.None).Where(l => !l.StartsWith(';'));
        var text = $"Windows Registry Editor Version 5.00\r\n\r\n[HKEY_CURRENT_USER\\Akari]\r\n{string.Join("\r\n", lines)}\r\n";
        return RegReader.Parse(text).Keys.Single().Values;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var accounts = Accounts(c);
        if (accounts.Count == 0) { c.Log.Write("No account settings yet: nothing to change"); return; }
        var values = Values(tweak, c);
        foreach (var g in accounts)
            foreach (var v in values)
                c.Registry.SetValue($@"{Current}\{g}${Profile}", v.Name, v.Data, v.Kind.ToString());
    }
}
