using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/NotepadPlusPlus.ps1: after the winget install, Akari's config (Files/NotepadPlusPlus,
/// byte for byte) for the real user.</summary>
[TweakCode("install-notepad")]
public sealed class NotepadPlusPlus : ITweakCode
{
    public void After(Tweak tweak, TweakContext c, TweakMode mode) =>
        AppFiles.CopyFile(tweak, c, "NotepadPlusPlus/config.xml", Path.Combine(AppFiles.User(c, "AppData"), @"Notepad++\config.xml"));
}
