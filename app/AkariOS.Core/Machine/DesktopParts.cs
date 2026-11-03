using System.Diagnostics;
using System.Runtime.InteropServices;

namespace AkariOS.Core.Machine;

// TweakServices' desktop parts: an interface each (tests fake them) and the real one, guarded (rule 12).

/// <summary>Stops a running program by name (Stop-Process -Name -Force): Start's host, so it reads its pins again.</summary>
public interface IProcesses
{
    void Stop(string name);
}

/// <summary>The real one (guarded); a program that isn't running is nothing to do.</summary>
public sealed class Processes : IProcesses
{
    public Processes() => SystemGuard.Check("Stopping programs");

    public void Stop(string name)
    {
        foreach (var p in Process.GetProcessesByName(name))
            using (p)
                try { p.Kill(); } catch (Exception e) when (e is InvalidOperationException or System.ComponentModel.Win32Exception) { }
    }
}

/// <summary>A .lnk shortcut (WScript.Shell's CreateShortcut); a working folder when given (New-AkariShortcut sets it).</summary>
public interface IShortcuts
{
    void Create(string link, string target, string? workingDirectory = null);
}

/// <summary>The real one: WScript.Shell through COM (guarded).</summary>
public sealed class Shortcuts : IShortcuts
{
    public Shortcuts() => SystemGuard.Check("Shortcuts");

    public void Create(string link, string target, string? workingDirectory = null)
    {
        dynamic shell = Activator.CreateInstance(Type.GetTypeFromProgID("WScript.Shell", throwOnError: true)!)!;
        dynamic s = shell.CreateShortcut(link);
        s.TargetPath = target;
        if (workingDirectory is not null) s.WorkingDirectory = workingDirectory;
        s.Save();
    }
}

/// <summary>The desktop: its wallpaper shown now (Set-AkariDesktopWallpaper; the Tweak writes the registry), the main
/// screen's size.</summary>
public interface IDesktop
{
    void SetWallpaper(string path);

    (int Width, int Height) ScreenSize();
}

/// <summary>The real one: SystemParametersInfo and GetSystemMetrics (guarded).</summary>
public sealed partial class Desktop : IDesktop
{
    public Desktop() => SystemGuard.Check("The desktop");

    private const uint SetDeskWallpaper = 20, UpdateIniFile = 1, SendChange = 2;

    public void SetWallpaper(string path)
    {
        if (!SystemParametersInfoW(SetDeskWallpaper, 0, path, UpdateIniFile | SendChange)) throw new System.ComponentModel.Win32Exception();
    }

    public (int Width, int Height) ScreenSize() => (GetSystemMetrics(0), GetSystemMetrics(1));

    [LibraryImport("user32.dll", SetLastError = true, StringMarshalling = StringMarshalling.Utf16)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool SystemParametersInfoW(uint action, uint param, string value, uint flags);

    [LibraryImport("user32.dll")]
    private static partial int GetSystemMetrics(int index);
}
