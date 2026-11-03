using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Apps;

/// <summary>src/Tweaks/Customize/Apps/NotepadSettings.ps1: three values in Notepad's settings hive, Notepad stopped
/// first; Revert deletes the settings file (Notepad starts over with its own defaults).</summary>
[TweakCode("apps-notepad-settings")]
public sealed class NotepadSettings : ITweakCode
{
    public TweakState Detect(Tweak tweak, TweakContext c) => AppHive.State(tweak, c);

    public void Apply(Tweak tweak, TweakContext c, object? value) => AppHive.Change(tweak, c, "Apply");

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        AppHive.Prepare(AppHive.Block(tweak, "Revert"), c);
        var dat = AppHive.Dat(tweak, c);
        if (File.Exists(dat)) File.Delete(dat);
    }
}
