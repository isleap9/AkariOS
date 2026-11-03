using System.Diagnostics;

namespace AkariOS.Core.Machine;

/// <summary>Restarting the PC (Restart-AkariPC; the firmware restart comes with the Tools, N8).</summary>
public interface IShutdown
{
    void Restart();
}

/// <summary>The real one: shutdown /r /t 0 (guarded: never in a test).</summary>
public sealed class ShutdownExe : IShutdown
{
    public ShutdownExe() => SystemGuard.Check("the PC's restart");

    public void Restart()
    {
        var exe = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "shutdown.exe");
        using var p = Process.Start(new ProcessStartInfo(exe, "/r /t 0") { UseShellExecute = false, CreateNoWindow = true });
    }
}
