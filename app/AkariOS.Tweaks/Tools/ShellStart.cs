using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools;

/// <summary>
/// Start-Process as the Tools blocks use it, never waited for: a URI (ms-settings:, https:) through the launcher, a
/// Control Panel file through control.exe, a console (.msc) through mmc.exe, a bare program name from System32 (explorer.exe from the Windows folder),
/// a full path as it is.
/// </summary>
internal static class ShellStart
{
    public static void Run(TweakContext c, string target, string arguments = "")
    {
        if (IsUri(target))
        {
            TweakServices.Need(c.Services.Launcher, "launcher").Open(target);
            return;
        }
        var windows = TweakServices.Folder(c.Services.Windows, "Windows");
        var (path, args) = target switch
        {
            _ when target.EndsWith(".cpl", StringComparison.OrdinalIgnoreCase) => (Path.Combine(windows, "System32", "control.exe"), target),
            _ when target.EndsWith(".msc", StringComparison.OrdinalIgnoreCase) => (Path.Combine(windows, "System32", "mmc.exe"), target),
            _ when Path.IsPathRooted(target) => (target, arguments),
            _ when string.Equals(target, "explorer.exe", StringComparison.OrdinalIgnoreCase) => (Path.Combine(windows, target), arguments),
            _ => (Path.Combine(windows, "System32", target), arguments),
        };
        TweakServices.Need(c.Services.Exe, "program runner").Run(path, args, wait: false);
    }

    /// <summary>A web search (the blocks' Google search, its text escaped as [uri]::EscapeDataString does).</summary>
    public static void Search(TweakContext c, string text) => Run(c, "https://www.google.com/search?q=" + Escape(text));

    /// <summary>[uri]::EscapeDataString in Windows PowerShell 5.1 (RFC 2396: the marks ! * ' ( ) stay as they are;
    /// .NET 10 escapes them too).</summary>
    public static string Escape(string text) => Uri.EscapeDataString(text)
        .Replace("%21", "!").Replace("%2A", "*").Replace("%27", "'").Replace("%28", "(").Replace("%29", ")");

    private static bool IsUri(string target) =>
        target.StartsWith("https:", StringComparison.OrdinalIgnoreCase) || target.StartsWith("ms-settings:", StringComparison.OrdinalIgnoreCase);

    /// <summary>The motherboard as the blocks name it ("&lt;Manufacturer&gt; &lt;Product&gt;"; WMI's Win32_BaseBoard).</summary>
    public static string Board(TweakContext c)
    {
        var b = TweakServices.Need(c.Services.Hardware, "hardware reader").Board() ?? new BoardInfo("", "");
        return $"{b.Manufacturer} {b.Product}";
    }
}
