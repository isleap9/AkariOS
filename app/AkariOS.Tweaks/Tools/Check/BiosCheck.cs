using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Check;

/// <summary>src/Tweaks/Tools/Check/BiosCheck.ps1: the board and BIOS version in the console (WMI), the BIOS settings
/// worth changing, and a web search for the board's latest BIOS. An Action: a check, it changes nothing.</summary>
[TweakCode("tools-bios-check")]
public sealed class BiosCheck : ITweakCode
{
    private static readonly string[] Advice =
    [
        "Update the BIOS, then in its settings:",
        "- turn on the RAM profile (XMP / DOCP / EXPO) and Resizable BAR (ReBAR / C.A.M)",
        "- Intel K CPUs: turn off C-states; AMD CPUs: turn on Precision Boost Overdrive (PBO)",
        "- turn off what you don't use (Bluetooth, Wi-Fi, integrated GPU) and the driver installer (Armoury Crate, MSI Driver Utility, ...)",
        "- fans and pump on performance; TPM and Secure Boot on for anti-cheat games",
        "Restart to BIOS (Tools > Refresh) gets you there.",
    ];

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var board = ShellStart.Board(c);
        var bios = TweakServices.Need(c.Services.Hardware, "hardware reader").Bios() ?? new BiosInfo("", null);
        var date = bios.Released is { } d ? " from " + d.ToString("yyyy-MM-dd", System.Globalization.CultureInfo.InvariantCulture) : "";
        c.Log.Write($"Motherboard: {board}, BIOS {bios.Version}{date}");
        foreach (var l in Advice) c.Log.Write(l);
        ShellStart.Search(c, $"{board} BIOS");
    }
}
