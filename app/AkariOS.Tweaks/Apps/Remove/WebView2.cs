using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Remove;

/// <summary>src/Tweaks/Apps/Remove/WebView2.ps1: the WebView2 runtime (its uninstaller, Edge Update kept from putting it
/// back, its folder and uninstall entry), and Edge Update once Edge is gone too. Kept out of the AkariOS pick. An
/// Action: WebView2 comes back from Microsoft's installer. Done = no EdgeWebView\Application folder.</summary>
[TweakCode("remove-webview2")]
public sealed class WebView2 : ITweakCode
{
    private const string Uninstall = @"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Microsoft EdgeWebView";

    private static string X86(TweakContext c) => TweakServices.Folder(c.Services.ProgramFilesX86, "Program Files (x86)");

    public TweakState Detect(Tweak tweak, TweakContext c) =>
        Directory.Exists(Path.Combine(X86(c), @"Microsoft\EdgeWebView\Application")) ? TweakState.Default : TweakState.Optimized;

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        FileData.Need(c.Services.Processes, "process list").Stop("msedgewebview2");
        c.Registry.SetValue(EdgeUpdate.Dev, "AllowUninstall", 1, "DWord");
        if (c.Registry.GetValue(Uninstall, "UninstallString") is string u && u.Length > 0)
            FileData.Need(c.Services.Exe, "program runner").Run(Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "System32", "cmd.exe"), $"/c {u} --force-uninstall");
        // Edge Update must not put it back
        c.Registry.SetValue(EdgeUpdate.Policies, "Install{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}", 0, "DWord");
        Files.Delete(Path.Combine(X86(c), @"Microsoft\EdgeWebView"));
        c.Registry.DeleteKey(Uninstall);
        // Edge already gone too: Edge Update has nothing left to update
        if (!File.Exists(Path.Combine(X86(c), @"Microsoft\Edge\Application\msedge.exe"))) EdgeUpdate.Remove(c);
    }
}
