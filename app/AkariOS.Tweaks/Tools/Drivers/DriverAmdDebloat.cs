using System.Text.RegularExpressions;
using AkariOS.Core.Apps;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;
using AkariOS.Tweaks.Apps.Remove;

namespace AkariOS.Tweaks.Tools.Drivers;

/// <summary>src/Tweaks/Tools/Drivers/DriverAmdDebloat.ps1: the newest full Adrenalin package in Downloads, unpacked, its
/// optional parts off in its config, installed; then Crash Defender, the audio co-processor drivers, the bug report tool,
/// Install Manager and their startup entries removed. An Action: DDU (tools-ddu-clean) removes it.</summary>
[TweakCode("tools-driver-amd-debloat")]
public sealed partial class DriverAmdDebloat : ITweakCode
{
    /// <summary>Config\&lt;name&gt;.xml: not installed, not offered.</summary>
    public static readonly string[] Optional =
    [
        "AMDAUEPInstaller", "AMDCOMPUTE", "AMDLinkDriverUpdate", "AMDRELAUNCHER", "AMDScoSupportTypeUpdate", "AMDUpdater", "AMDUWPLauncher",
        "EnableWindowsDriverSearch", "InstallUEP", "ModifyLinkUpdate",
    ];

    public static readonly string[] Services = ["AMD Crash Defender Service", "amdfendr", "amdfendrmgr", "amdacpbus", "AMDSAFD", "AtiHDAudioService"];

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var pkg = DriverSteps.Package(c, "*amd-software-adrenalin-edition*.exe", "*minimalsetup*", DriverAmd.Page, "AMD");
        var dir = DriverSteps.Temp(c, "amddriver");
        DriverSteps.Expand(c, pkg, dir);
        // the block's -replace: case-insensitive
        foreach (var x in Optional)
            DriverSteps.EditText(Path.Combine(dir, "Config", $"{x}.xml"), t => Regex.Replace(
                Regex.Replace(t, "<Enabled>true</Enabled>", "<Enabled>false</Enabled>", RegexOptions.IgnoreCase),
                "<Hidden>true</Hidden>", "<Hidden>false</Hidden>", RegexOptions.IgnoreCase));
        foreach (var f in new[] { Path.Combine(dir, "Config", "InstallManifest.json"), Path.Combine(dir, "Bin64", "cccmanifest_64.json") })
            DriverSteps.EditText(f, t => ByDefault().Replace(t, "\"InstallByDefault\" : \"No\""));
        c.Log.Write("Installing the AMD driver");
        DriverSteps.Install(c, Path.Combine(dir, "Bin64", "ATISetup.exe"), "AMD setup", "-INSTALL", "-VIEW:2");
        AppSetup.RemoveStartup(c, "AMDNoiseSuppression");
        AppSetup.RemoveStartup(c, ["StartRSX"], [@"HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"]);
        Tasks.Unregister(c, n => string.Equals(n, "StartCN", StringComparison.OrdinalIgnoreCase));
        DriverSteps.RemoveServices(c, Services);
        DriverSteps.Delete(Path.Combine(TweakServices.Folder(c.Services.ProgramData, "ProgramData"), @"Microsoft\Windows\Start Menu\Programs\AMD Bug Report Tool"),
            Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), @"SysWOW64\AMDBugReportTool.exe"));
        AppSetup.UninstallMsi(c, "*AMD Install Manager*");
        DriverSteps.Delete(pkg, dir, Path.Combine(TweakServices.Folder(c.Services.SystemDrive, "system drive"), "AMD"));
    }

    [GeneratedRegex("\"InstallByDefault\"\\s*:\\s*\"Yes\"", RegexOptions.IgnoreCase)]
    private static partial Regex ByDefault();
}
