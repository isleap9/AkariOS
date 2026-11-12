using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Check;

/// <summary>src/Tweaks/Tools/Check/MousePollingTest.ps1: Mouse Movement Recorder from AkariOS-Files (the first time), a
/// Start menu shortcut, then opened. An Action: it installs and opens a test tool.</summary>
[TweakCode("tools-mouse-polling-test")]
public sealed class MousePollingTest : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) =>
        PortableTool.Open(c, "mousemovementrecorder.exe", @"Mouse Movement Recorder\Mouse Movement Recorder.exe", "Mouse Movement Recorder");
}
