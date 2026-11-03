using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Hardware.Graphics;

/// <summary>
/// src/Tweaks/Hardware/Graphics/AmdSettings.ps1: AMD Software opened for 30 s and closed (so it has written its keys),
/// then its HKCU settings and, per AMD adapter key, Anti-Lag and the UMD / power_v1 values (only where the driver made
/// those subkeys); the notifications marked as seen. Revert = the old script's Default.
/// </summary>
[TweakCode("graphics-amd-settings")]
public sealed class AmdSettings : ITweakCode
{
    private const string Cn = @"HKCU:\Software\AMD\CN";
    private const string Dvr = @"HKCU:\Software\AMD\DVR";
    private const string Aim = @"HKCU:\Software\AMD\AIM";

    private static readonly (string Name, string Value)[] CnStrings =
    [
        ("SystemTray", "false"), ("RSXBrowserUnavailable", "true"), ("AllowWebContent", "false"), ("CN_Hide_Toast_Notification", "true"),
        ("AnimationEffect", "false"), ("WizardProfile", "PROFILE_CUSTOM"),
    ];

    private static readonly string[] Notified = ["FreeSync", "OverlayNotification", "VirtualSuperResolution"];

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var w = c.Registry.GetValue(Cn, "WizardProfile");
        var a = c.Registry.GetValue(Cn, "AllowWebContent");
        if (PsSemantics.LooseEquals(w, "PROFILE_CUSTOM") && PsSemantics.LooseEquals(a, "false")) return TweakState.Optimized;
        return w is null && a is null ? TweakState.Default : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var s = c.Services;
        var rs = Path.Combine(TweakServices.Folder(s.ProgramFiles, "Program Files"), @"AMD\CNext\CNext\RadeonSoftware.exe");
        if (File.Exists(rs))
        {
            FileData.Need(s.Exe, "program runner").Run(rs, "", wait: false);
            s.Sleep(TimeSpan.FromSeconds(30));
            FileData.Need(s.Processes, "process control").Stop("RadeonSoftware");
            s.Sleep(TimeSpan.FromSeconds(2));
        }
        var reg = c.Registry;
        reg.SetValue(Cn, "AutoUpdate", 0, "DWord");
        reg.SetValue(Aim, "LaunchBugTool", 0, "DWord");
        reg.SetValue(Dvr, "HotkeysDisabled", 1, "DWord");
        reg.SetValue(Dvr, "ShowRSOverlay", "false", "String");
        foreach (var (n, v) in CnStrings) reg.SetValue(Cn, n, v, "String");
        reg.SetValue($@"{Cn}\CustomResolutions", "EulaAccepted", "true", "String");
        reg.SetValue($@"{Cn}\DisplayOverride", "EulaAccepted", "true", "String");
        foreach (var g in GpuValues.Of(c, "AMD"))
        {
            reg.SetValue(g.Path, "KMD_DeLagEnabled", 1, "DWord");
            reg.SetValue(g.Path, "IsAutoDefault", new byte[] { 0, 0, 0, 0 }, "Binary");
            reg.SetValue(g.Path, "IsComponentControl", new byte[] { 0x0f, 0, 0, 0 }, "Binary");
            if (reg.KeyExists($@"{g.Path}\UMD"))
            {
                reg.SetValue($@"{g.Path}\UMD", "VSyncControl", new byte[] { 0x30, 0 }, "Binary");
                reg.SetValue($@"{g.Path}\UMD", "TFQ", new byte[] { 0x32, 0 }, "Binary");
                reg.SetValue($@"{g.Path}\UMD", "Tessellation", new byte[] { 0x31, 0 }, "Binary");
                reg.SetValue($@"{g.Path}\UMD", "Tessellation_OPTION", new byte[] { 0x32, 0 }, "Binary");
            }
            if (reg.KeyExists($@"{g.Path}\power_v1")) reg.SetValue($@"{g.Path}\power_v1", "abmlevel", new byte[] { 0, 0, 0, 0 }, "Binary");
        }
        // notifications already seen
        reg.DeleteKey($@"{Cn}\Notification");
        reg.CreateKey($@"{Cn}\Notification");
        foreach (var k in Notified) reg.SetValue($@"{Cn}\{k}", "AlreadyNotified", 1, "DWord");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        var reg = c.Registry;
        reg.RemoveValue(Cn, "AutoUpdate");
        reg.SetValue(Aim, "LaunchBugTool", 1, "DWord");
        reg.RemoveValue(Dvr, "HotkeysDisabled");
        reg.RemoveValue(Dvr, "ShowRSOverlay");
        foreach (var (n, _) in CnStrings) reg.RemoveValue(Cn, n);
        foreach (var g in GpuValues.Of(c, "AMD"))
        {
            reg.SetValue(g.Path, "KMD_DeLagEnabled", 0, "DWord");
            reg.SetValue(g.Path, "IsAutoDefault", 1, "DWord");
            reg.SetValue(g.Path, "IsComponentControl", new byte[] { 0, 0, 0, 0 }, "Binary");
            if (reg.KeyExists($@"{g.Path}\UMD"))
            {
                reg.SetValue($@"{g.Path}\UMD", "VSyncControl", new byte[] { 0x31, 0, 0, 0 }, "Binary");
                reg.RemoveValue($@"{g.Path}\UMD", "TFQ");
                reg.SetValue($@"{g.Path}\UMD", "Tessellation", new byte[] { 0x36, 0, 0x34, 0, 0, 0 }, "Binary");
                reg.SetValue($@"{g.Path}\UMD", "Tessellation_OPTION", new byte[] { 0x30, 0, 0, 0 }, "Binary");
            }
            if (reg.KeyExists($@"{g.Path}\power_v1")) reg.RemoveValue($@"{g.Path}\power_v1", "abmlevel");
        }
        foreach (var k in new[] { "CustomResolutions", "DisplayOverride", "Notification" }.Concat(Notified)) reg.DeleteKey($@"{Cn}\{k}");
    }
}
