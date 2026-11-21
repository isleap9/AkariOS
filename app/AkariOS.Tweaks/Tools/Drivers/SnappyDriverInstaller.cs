using AkariOS.Core.Apps;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Drivers;

/// <summary>src/Tweaks/Tools/Drivers/SnappyDriverInstaller.ps1 (from winutil's apps): Snappy Driver Installer Origin
/// (Open-AkariWingetTool: winget's GlennDelahoy.SnappyDriverInstallerOrigin installed first when SDIO_x64_*.exe is
/// missing). An Action: it opens a tool.</summary>
[TweakCode("tools-snappy-driver-installer")]
public sealed class SnappyDriverInstaller : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) =>
        AppSetup.OpenTool(c, "GlennDelahoy.SnappyDriverInstallerOrigin", "SDIO_x64_*.exe");
}
