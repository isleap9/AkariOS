using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Remove;

/// <summary>src/Tweaks/Apps/Remove/Edge.ps1: the Edge browser only (WebView2 and Edge Update stay for the apps that need
/// them): its uninstaller (allowed first, with the empty legacy Edge file it wants), Edge Update kept from putting it
/// back, the leftovers, Windows 10's built-in Edge package; Edge Update too once WebView2 is gone. An Action: Edge comes
/// back from Microsoft's installer. Done = no msedge.exe.</summary>
[TweakCode("remove-edge")]
public sealed class Edge : ITweakCode
{
    private const string Uninstall = @"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft Edge";
    private const string Cbs = @"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages";

    private static string X86(TweakContext c) => TweakServices.Folder(c.Services.ProgramFilesX86, "Program Files (x86)");

    public TweakState Detect(Tweak tweak, TweakContext c) =>
        File.Exists(Path.Combine(X86(c), @"Microsoft\Edge\Application\msedge.exe")) ? TweakState.Default : TweakState.Optimized;

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var processes = FileData.Need(c.Services.Processes, "process list");
        foreach (var p in processes.Running().Where(p => PsSemantics.Like(p, "msedge*") && !string.Equals(p, "msedgewebview2", StringComparison.OrdinalIgnoreCase)))
            processes.Stop(p);
        // Edge's uninstaller refuses unless uninstalling is allowed and this (empty) legacy Edge file exists
        c.Registry.SetValue(EdgeUpdate.Dev, "AllowUninstall", 1, "DWord");
        var windows = TweakServices.Folder(c.Services.Windows, "Windows");
        var legacy = Path.Combine(windows, @"SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe");
        Directory.CreateDirectory(legacy);
        File.WriteAllBytes(Path.Combine(legacy, "MicrosoftEdge.exe"), []);
        var exe = FileData.Need(c.Services.Exe, "program runner");
        if (c.Registry.GetValue(Uninstall, "UninstallString") is string u && u.Length > 0)
            exe.Run(Path.Combine(windows, "System32", "cmd.exe"), $"/c {u} --force-uninstall");
        Files.Delete(legacy);
        // Edge Update must not put it back (WebView2 keeps updating)
        c.Registry.SetValue(EdgeUpdate.Policies, "Install{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}", 0, "DWord");
        c.Registry.SetValue(EdgeUpdate.Policies, "DoNotUpdateToEdgeWithChromium", 1, "DWord");
        // leftovers: folder, uninstall entry, shortcuts, elevation service
        Files.Delete(Path.Combine(X86(c), @"Microsoft\Edge"));
        c.Registry.DeleteKey(Uninstall);
        Files.Delete(Path.Combine(TweakServices.Folder(c.Services.Public, "Public"), @"Desktop\Microsoft Edge.lnk"));
        Files.Delete(Path.Combine(TweakServices.Folder(c.Services.ProgramData, "ProgramData"), @"Microsoft\Windows\Start Menu\Programs\Microsoft Edge.lnk"));
        Files.Delete(Path.Combine(FileData.UserFolder(c, "AppData"), @"Microsoft\Internet Explorer\Quick Launch\Microsoft Edge.lnk"));
        EdgeUpdate.RemoveService(c, "MicrosoftEdgeElevationService");
        // Windows 10: the old built-in Edge package
        foreach (var p in c.Registry.SubKeys(Cbs).Where(k => PsSemantics.Like(k, "*Microsoft-Windows-Internet-Browser-Package*~~*")))
        {
            c.Registry.SetValue($@"{Cbs}\{p}", "Visibility", 1, "DWord");
            c.Registry.DeleteKey($@"{Cbs}\{p}\Owners");
            exe.Run(Path.Combine(windows, "System32", "dism.exe"), $"/online /Remove-Package /PackageName:{p} /quiet /norestart");
        }
        // WebView2 already gone too: Edge Update has nothing left to update
        if (!Directory.Exists(Path.Combine(X86(c), @"Microsoft\EdgeWebView\Application"))) EdgeUpdate.Remove(c);
    }
}
