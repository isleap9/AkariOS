using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Fixes;

/// <summary>src/Tweaks/Tools/Fixes/NetworkReset.ps1 (winutil's Invoke-WPFFixesNetwork): netsh winsock reset, netsh int
/// ip reset. An Action that wants a restart (Reboot).</summary>
[TweakCode("tools-fix-network")]
public sealed class NetworkReset : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var netsh = Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "System32", "netsh.exe");
        var exe = TweakServices.Need(c.Services.Exe, "program runner");
        exe.Run(netsh, ExeArgs.Join("winsock", "reset"));
        exe.Run(netsh, ExeArgs.Join("int", "ip", "reset"));
        c.Log.Write("Network reset: done. Restart Windows to finish.");
    }
}
