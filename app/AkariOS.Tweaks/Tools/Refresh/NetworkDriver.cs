using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Refresh;

/// <summary>src/Tweaks/Tools/Refresh/NetworkDriver.ps1: the board in the console and a web search for its network
/// driver. An Action: it opens a search.</summary>
[TweakCode("tools-network-driver")]
public sealed class NetworkDriver : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var board = ShellStart.Board(c);
        c.Log.Write($"Motherboard: {board}");
        ShellStart.Search(c, $"{board} network driver");
    }
}
