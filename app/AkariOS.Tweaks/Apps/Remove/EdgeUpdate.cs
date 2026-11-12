using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Remove;

/// <summary>Edge Update, which Edge.ps1 and WebView2.ps1 both remove once the other app is gone too (the same steps in
/// both files): its process, each version's MicrosoftEdgeUpdate.exe /unregsvc and /uninstall, its services and tasks,
/// its folder.</summary>
internal static class EdgeUpdate
{
    public const string Dev = @"HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdateDev";
    public const string Policies = @"HKLM:\SOFTWARE\Policies\Microsoft\EdgeUpdate";

    /// <summary>Stopped, then deleted (Stop-Service; Remove-AkariService), when it is on this PC.</summary>
    public static void RemoveService(TweakContext c, string name)
    {
        var services = FileData.Need(c.Services.Services, "service manager");
        if (services.StartType(name) is null) return;
        services.Stop(name);
        services.Delete(name);
    }

    public static void Remove(TweakContext c)
    {
        FileData.Need(c.Services.Processes, "process list").Stop("MicrosoftEdgeUpdate");
        var folder = Path.Combine(TweakServices.Folder(c.Services.ProgramFilesX86, "Program Files (x86)"), @"Microsoft\EdgeUpdate");
        var exe = FileData.Need(c.Services.Exe, "program runner");
        if (Directory.Exists(folder))
            foreach (var version in Directory.GetDirectories(folder).Where(d => PsSemantics.Like(Path.GetFileName(d), "*.*.*.*")).Order(StringComparer.OrdinalIgnoreCase))
            {
                var update = Path.Combine(version, "MicrosoftEdgeUpdate.exe");
                if (!File.Exists(update)) continue;
                exe.Run(update, "/unregsvc");
                exe.Run(update, "/uninstall");
            }
        foreach (var s in FileData.Need(c.Services.Services, "service manager").Names().Where(n => PsSemantics.Like(n, "edgeupdate*")).ToList())
            RemoveService(c, s);
        Tasks.Unregister(c, n => PsSemantics.Like(n, "*EdgeUpdate*"));
        Files.Delete(folder);
    }
}
