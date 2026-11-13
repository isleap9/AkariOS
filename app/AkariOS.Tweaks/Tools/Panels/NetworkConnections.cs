using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Panels;

/// <summary>src/Tweaks/Tools/Panels/NetworkConnections.ps1: Network Connections, ncpa.cpl (an Action: it opens a window).</summary>
[TweakCode("tools-panel-network")]
public sealed class NetworkConnections : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => ShellStart.Run(c, "ncpa.cpl");
}
