using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

/// <summary>src/Tweaks/Apps/Install/MoreClockTool.ps1: More Clock Tool from AkariOS-Files, with a Start menu
/// shortcut.</summary>
[TweakCode("install-more-clock-tool")]
public sealed class MoreClockTool : ITweakCode
{
    private static string Exe(TweakContext c) => Download.X86(c, @"More Clock Tool\More Clock Tool.exe");

    public TweakState Detect(Tweak tweak, TweakContext c) => Download.Done(Exe(c));

    public void Apply(Tweak tweak, TweakContext c, object? value) => Download.Tool(c, "More Clock Tool", "moreclocktool.exe", Exe(c));
}
