using System.Diagnostics;

namespace AkariOS.Core.Machine;

/// <summary>Explorer's restart: changes to the taskbar, Start or the context menu show only after it.</summary>
public interface IExplorer
{
    void Restart();
}

/// <summary>
/// The real one (Restart-AkariExplorer): stops explorer.exe, and Windows starts the shell again by itself as the
/// signed-in user (starting it from this elevated process would run it elevated); only when it isn't back after
/// 5 seconds (shell restart turned off) is it started here, better elevated than no taskbar.
/// </summary>
public sealed class ExplorerShell : IExplorer
{
    public ExplorerShell() => SystemGuard.Check("Explorer's restart");

    public void Restart()
    {
        foreach (var p in Process.GetProcessesByName("explorer"))
            using (p)
                try { p.Kill(); } catch (Exception e) when (e is InvalidOperationException or System.ComponentModel.Win32Exception) { }
        for (var i = 0; i < 10 && !Running(); i++) Thread.Sleep(500);
        if (!Running()) Process.Start(new ProcessStartInfo(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), "explorer.exe")) { UseShellExecute = true })?.Dispose();
    }

    private static bool Running()
    {
        var ps = Process.GetProcessesByName("explorer");
        foreach (var p in ps) p.Dispose();
        return ps.Length > 0;
    }
}
