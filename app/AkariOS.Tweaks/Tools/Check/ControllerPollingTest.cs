using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Check;

/// <summary>src/Tweaks/Tools/Check/ControllerPollingTest.ps1: Gamepadla's Polling from AkariOS-Files (the first time),
/// a Start menu shortcut, then opened. An Action: it installs and opens a test tool.</summary>
[TweakCode("tools-controller-polling-test")]
public sealed class ControllerPollingTest : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value) => PortableTool.Open(c, "polling.exe", @"Polling\Polling.exe", "Polling");
}
