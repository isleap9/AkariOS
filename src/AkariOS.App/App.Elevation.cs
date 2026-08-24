using System.Diagnostics;
using System.Security.Principal;
using Microsoft.UI.Xaml;

namespace AkariOS.App;

public partial class App
{
    /// <summary>True when running elevated (Administrator).</summary>
    private static bool IsElevated()
    {
        using var identity = WindowsIdentity.GetCurrent();
        return new WindowsPrincipal(identity).IsInRole(WindowsBuiltInRole.Administrator);
    }

    /// <summary>
    /// Relaunches itself elevated and exits. Returns true if a relaunch was initiated
    /// (the caller must return immediately without touching UI).
    /// </summary>
    private static bool RelaunchElevatedIfRequired()
    {
        if (IsElevated()) return false;

        var exe = Environment.ProcessPath;
        if (exe is null || string.IsNullOrWhiteSpace(exe)) return false;

        // Pass a flag so we don't loop if elevation is declined.
        var args = Environment.GetCommandLineArgs().Skip(1);
        var psi = new ProcessStartInfo
        {
            FileName = exe,
            Arguments = string.Join(' ', args),
            UseShellExecute = true,
            Verb = "runas",
        };
        try
        {
            Process.Start(psi);
            Environment.Exit(0);
            return true;
        }
        catch (Exception)
        {
            // User clicked "No" on the UAC prompt — keep running unprivileged
            // so we can show an explanation instead of silently dying.
            return false;
        }
    }
}
