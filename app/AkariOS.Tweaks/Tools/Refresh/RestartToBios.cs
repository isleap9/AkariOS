using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Refresh;

/// <summary>src/Tweaks/Tools/Refresh/RestartToBios.ps1: shutdown /r /fw (IShutdown.Firmware); not 0 = not a UEFI PC, the
/// Action fails saying so. Restarts: the Runner runs it last. An Action: a restart.</summary>
[TweakCode("tools-restart-to-bios")]
public sealed class RestartToBios : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var code = TweakServices.Need(c.Services.Shutdown, "restart").Firmware();
        if (code != 0) throw new InvalidOperationException($"this PC can't restart into its firmware settings (shutdown /fw: exit code {code}; not a UEFI PC?)");
    }
}
