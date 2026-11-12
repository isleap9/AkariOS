using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.OneClick.Prepare;

/// <summary>src/Tweaks/OneClick/Prepare/AllowScripts.ps1: a .ps1 opens in PowerShell on double-click and the execution
/// policy is Unrestricted (the machine's and the real user's). An Action: there is no single Default to go back to.</summary>
[TweakCode("oneclick-allow-scripts")]
public sealed class AllowScripts : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var windows = TweakServices.Folder(c.Services.Windows, "Windows");
        c.Registry.SetValue(@"HKLM:\SOFTWARE\Classes\Applications\powershell.exe\shell\open\command", "(default)",
            $"{windows}\\System32\\WindowsPowerShell\\v1.0\\powershell.exe -NoLogo -ExecutionPolicy unrestricted -File \"%1\"", "String");
        c.Registry.SetValue(@"HKCU:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell", "ExecutionPolicy", "Unrestricted", "String");
        c.Registry.SetValue(@"HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell", "ExecutionPolicy", "Unrestricted", "String");
    }
}
