using System.Diagnostics;

namespace AkariOS.Core.Machine;

/// <summary>Restarting the PC (Restart-AkariPC), and into its firmware settings (Restart-AkariFirmware, Tools › Refresh).</summary>
public interface IShutdown
{
    void Restart();

    /// <summary>shutdown /r /fw /t 0: its exit code (not 0 on a PC without UEFI).</summary>
    int Firmware() => throw new NotSupportedException("this engine can't restart into the firmware settings");
}

/// <summary>The real one: shutdown.exe (guarded: never in a test).</summary>
public sealed class ShutdownExe : IShutdown
{
    public ShutdownExe() => SystemGuard.Check("the PC's restart");

    private static string Exe => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "shutdown.exe");

    public void Restart()
    {
        using var p = Process.Start(new ProcessStartInfo(Exe, "/r /t 0") { UseShellExecute = false, CreateNoWindow = true });
    }

    public int Firmware() => Tool.Run(Exe, ["/r", "/fw", "/t", "0"]).ExitCode;
}
