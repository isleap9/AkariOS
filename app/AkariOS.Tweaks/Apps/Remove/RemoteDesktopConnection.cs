using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Remove;

/// <summary>src/Tweaks/Apps/Remove/RemoteDesktopConnection.ps1: mstsc uninstalls itself. An Action: its installer
/// brings it back.</summary>
[TweakCode("remove-remote-desktop-connection")]
public sealed class RemoteDesktopConnection : ITweakCode
{
    public TweakState Detect(Tweak tweak, TweakContext c) => SelfUninstalling.Done(c, "mstsc.exe");
    public void Apply(Tweak tweak, TweakContext c, object? value) => SelfUninstalling.Run(c, "mstsc.exe", "mstsc");
}
