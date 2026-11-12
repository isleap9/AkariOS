using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Refresh;

/// <summary>src/Tweaks/Tools/Refresh/LocalAccount.ps1: the classic User Accounts window (netplwiz). An Action: it opens a
/// window.</summary>
[TweakCode("tools-local-account")]
public sealed class LocalAccount : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => ShellStart.Run(c, "netplwiz.exe");
}
