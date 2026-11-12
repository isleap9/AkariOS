using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Setup;

/// <summary>src/Tweaks/Tools/Setup/HomeToPro.ps1: Microsoft's generic Pro key on the clipboard and in the console, then
/// "Change product key". An Action: Windows has no way back to Home but a reinstall.</summary>
[TweakCode("tools-home-to-pro")]
public sealed class HomeToPro : ITweakCode
{
    public const string Key = "VK7JG-NPHTM-C97JM-9MPGT-3V66T";

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        TweakServices.Need(c.Services.Clipboard, "clipboard").SetText(Key);
        c.Log.Write($"Generic Pro key (copied): {Key}");
        ShellStart.Run(c, Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "System32", "SystemSettingsAdminFlows.exe"), "EnterProductKey");
    }
}
