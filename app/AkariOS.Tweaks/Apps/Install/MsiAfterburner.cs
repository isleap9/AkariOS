using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/MsiAfterburner.ps1: after the winget installs (Afterburner and RivaTuner), Akari's
/// settings and overlay: Files/Afterburner mirrors Program Files (x86).</summary>
[TweakCode("msi-afterburner")]
public sealed class MsiAfterburner : ITweakCode
{
    public void After(Tweak tweak, TweakContext c, TweakMode mode) =>
        AppFiles.CopyFolder(tweak, c, "Afterburner", AppFiles.Folder(c.Services.ProgramFilesX86, "Program Files (x86)"));
}
