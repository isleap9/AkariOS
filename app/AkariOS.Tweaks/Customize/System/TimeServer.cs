using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.SystemTweaks; // not .System: it would hide .NET's System namespace

/// <summary>src/Tweaks/Customize/System/TimeServer.ps1's After, both ways: the Windows Time service rereads its
/// NtpServer value and syncs (its output is only logged, as the block drops it).</summary>
[TweakCode("system-time-server")]
public sealed class TimeServer : ITweakCode
{
    public void After(Tweak tweak, TweakContext c, TweakMode mode)
    {
        var w32tm = FileData.Need(c.Services.W32tm, "w32tm");
        w32tm.Run("/config", "/update");
        w32tm.Run("/resync", "/nowait");
    }
}
