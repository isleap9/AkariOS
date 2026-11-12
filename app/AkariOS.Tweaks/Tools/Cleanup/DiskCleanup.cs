using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Cleanup;

/// <summary>src/Tweaks/Tools/Cleanup/DiskCleanup.ps1 (ZOICWARE): the categories this Windows has saved as Disk Cleanup
/// set 69 (StateFlags0069), then cleanmgr /sagerun:69. An Action: cleaned files can't come back.</summary>
[TweakCode("cleanup-disk-cleanup")]
public sealed class DiskCleanup : ITweakCode
{
    public const string Key = @"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches";

    /// <summary>ZOICWARE's list without the Recycle Bin and Windows ESD installation files.</summary>
    public static readonly string[] Categories =
    [
        "Active Setup Temp Folders", "Thumbnail Cache", "Delivery Optimization Files", "D3D Shader Cache", "Downloaded Program Files",
        "Internet Cache Files", "Setup Log Files", "Temporary Files", "Windows Error Reporting Files", "Offline Pages Files",
        "Temporary Setup Files", "Update Cleanup", "Upgrade Discarded Files", "Windows Defender", "Windows Reset Log Files",
        "Windows Upgrade Log Files", "Previous Installations", "Old ChkDsk Files", "Feedback Hub Archive log files",
        "Diagnostic Data Viewer database files", "Device Driver Packages",
    ];

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var set = 0;
        foreach (var k in Categories.Select(n => $@"{Key}\{n}").Where(c.Registry.KeyExists))
        {
            c.Registry.SetValue(k, "StateFlags0069", 2, "DWord");
            set++;
        }
        if (set == 0) throw new InvalidOperationException("Disk Cleanup has none of its categories on this PC");
        TweakServices.Need(c.Services.CleanMgr, "Disk Cleanup").Run(69);
        c.Log.Write($"Disk Cleanup ran with {set} categories");
    }
}
