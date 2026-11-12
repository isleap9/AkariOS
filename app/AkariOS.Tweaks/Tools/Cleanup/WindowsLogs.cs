using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;
using AkariOS.Tweaks.Advanced.SystemTweaks;

namespace AkariOS.Tweaks.Tools.Cleanup;

/// <summary>src/Tweaks/Tools/Cleanup/WindowsLogs.ps1 (ZOICWARE): Windows' setup, update, servicing and diagnostic logs;
/// the Update Medic logs (TrustedInstaller's) taken over by the administrators first. An Action: deleted logs can't come
/// back.</summary>
[TweakCode("cleanup-windows-logs")]
public sealed class WindowsLogs : ITweakCode
{
    /// <summary>Under %SystemRoot%, or the real user's Local AppData (%local%).</summary>
    public static readonly string[] Windows =
    [
        "DtcInstall.log", "comsetup.log", "PFRO.log", "setupact.log", "setuperr.log", "setupapi.log",
        @"Panther\*", @"inf\setupapi.app.log", @"inf\setupapi.dev.log", @"inf\setupapi.offline.log",
        @"Performance\WinSAT\winsat.log", @"debug\PASSWD.LOG", @"Logs\CBS\CBS.log", @"Logs\DISM\DISM.log",
        @"Logs\SIH\*", @"%local%\Microsoft\CLR_v4.0\UsageTraces\*", @"%local%\Microsoft\CLR_v4.0_32\UsageTraces\*",
        @"Logs\NetSetup\*", @"System32\LogFiles\setupcln\*", @"Temp\CBS\*", @"Logs\waasmedic",
        @"System32\catroot2\dberr.txt", @"System32\catroot2.log", @"System32\catroot2.jrs", @"System32\catroot2.edb",
        @"System32\catroot2.chk", @"Traces\WindowsUpdate\*",
    ];

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var w = TweakServices.Folder(c.Services.Windows, "Windows");
        var local = FileData.UserFolder(c, "Local AppData");
        SystemFiles.GrantOwnership(c, Path.Combine(w, @"Logs\waasmedic"));
        const string user = @"%local%\";
        var n = SystemPaths.Remove(Windows.Select(p => p.StartsWith(user, StringComparison.Ordinal) ? Path.Combine(local, p[user.Length..]) : Path.Combine(w, p)));
        c.Log.Write($"Deleted {n} log files and folders");
    }
}
