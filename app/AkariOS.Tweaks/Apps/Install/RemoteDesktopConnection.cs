using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/RemoteDesktopConnection.ps1: mstsc's installer from AkariOS-Files, after a
/// debloat removed it; done when mstsc.exe is back.</summary>
[TweakCode("install-remote-desktop-connection")]
public sealed class RemoteDesktopConnection : ITweakCode
{
    public TweakState Detect(Tweak tweak, TweakContext c) => Download.Done(Download.Windows(c, @"System32\mstsc.exe"));

    public void Apply(Tweak tweak, TweakContext c, object? value) =>
        Download.Install(c, "remotedesktopconnection.exe", Download.Windows(c, @"Temp\remotedesktopconnection.exe"));
}
