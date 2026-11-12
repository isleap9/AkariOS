using System.Diagnostics;
using System.Runtime.InteropServices;

namespace AkariOS.Core.Machine;

// The Tools' parts (N8): an interface each (tests fake them) and the real one, guarded (rule 12).

/// <summary>wevtutil.exe (Invoke-AkariWevtutil: "el" lists the event logs, "cl &lt;name&gt;" clears one): its output
/// lines, errors included as text.</summary>
public interface IWevtutil
{
    IReadOnlyList<string> Run(params string[] arguments);
}

/// <summary>Disk Cleanup with a saved set of categories (Invoke-AkariCleanMgr: cleanmgr /sagerun:&lt;n&gt;), waited for.</summary>
public interface ICleanMgr
{
    void Run(int set);
}

/// <summary>pnputil.exe (Remove-AkariDriverPackage: /delete-driver &lt;oemNN.inf&gt;, never /force): its exit code.</summary>
public interface IPnpUtil
{
    int DeleteDriver(string inf);
}

/// <summary>The clipboard (Set-Clipboard): text put on it.</summary>
public interface IClipboard
{
    void SetText(string text);
}

/// <summary>The motherboard (Win32_BaseBoard).</summary>
public sealed record BoardInfo(string Manufacturer, string Product);

/// <summary>The BIOS (Win32_BIOS): SMBIOSBIOSVersion and ReleaseDate (null when it says none).</summary>
public sealed record BiosInfo(string Version, DateTime? Released);

/// <summary>A drive with a letter and a size (Get-Volume): its letter, size and free space in bytes.</summary>
public sealed record VolumeInfo(char Letter, long Size, long Free);

public sealed class WevtutilExe : IWevtutil
{
    public WevtutilExe() => SystemGuard.Check("wevtutil");

    public IReadOnlyList<string> Run(params string[] arguments) =>
        Tool.Lines(Tool.Run(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "wevtutil.exe"), arguments).Output);
}

/// <summary>cleanmgr /sagerun:&lt;n&gt;, waited for 30 minutes at most; a Disk Cleanup whose CPU time and memory stop
/// changing for 30 seconds is taken as frozen and closed (as Invoke-AkariCleanMgr; after ZOICWARE).</summary>
public sealed class CleanMgrExe : ICleanMgr
{
    public CleanMgrExe() => SystemGuard.Check("Disk Cleanup");

    public void Run(int set)
    {
        var exe = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "cleanmgr.exe");
        using var p = Process.Start(new ProcessStartInfo(exe, $"/sagerun:{set}") { UseShellExecute = false })
            ?? throw new InvalidOperationException("Disk Cleanup did not start");
        var clock = Stopwatch.StartNew();
        string? last = null;
        var still = 0;
        while (!p.HasExited && clock.Elapsed.TotalMinutes < 30)
        {
            Thread.Sleep(TimeSpan.FromSeconds(10));
            p.Refresh();
            string now;
            try { now = $"{p.TotalProcessorTime}|{p.WorkingSet64}"; }
            catch (InvalidOperationException) { break; }
            still = now == last ? still + 1 : 0;
            last = now;
            if (still >= 3) break;
        }
        if (!p.HasExited) try { p.Kill(); } catch (Exception e) when (e is InvalidOperationException or System.ComponentModel.Win32Exception) { }
    }
}

public sealed class PnpUtilExe : IPnpUtil
{
    public PnpUtilExe() => SystemGuard.Check("pnputil");

    public int DeleteDriver(string inf) =>
        Tool.Run(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "pnputil.exe"), ["/delete-driver", inf]).ExitCode;
}

/// <summary>The clipboard through user32 (no WPF in Core, and a change runs off the UI thread): Unicode text.</summary>
public sealed partial class Clipboard : IClipboard
{
    private const uint UnicodeText = 13;
    private const uint Moveable = 0x0002;

    public Clipboard() => SystemGuard.Check("the clipboard");

    public void SetText(string text)
    {
        // another program may hold it for a moment
        var open = false;
        for (var i = 0; i < 10 && !(open = OpenClipboard(0)); i++) Thread.Sleep(100);
        if (!open) throw new InvalidOperationException("the clipboard is in use");
        try
        {
            EmptyClipboard();
            var bytes = (text.Length + 1) * 2;
            var mem = GlobalAlloc(Moveable, (nuint)bytes);
            if (mem == 0) throw new InvalidOperationException("no memory for the clipboard");
            var at = GlobalLock(mem);
            Marshal.Copy(text.ToCharArray(), 0, at, text.Length);
            Marshal.WriteInt16(at, text.Length * 2, 0);
            GlobalUnlock(mem);
            if (SetClipboardData(UnicodeText, mem) == 0)
            {
                GlobalFree(mem);
                throw new InvalidOperationException("the clipboard refused the text");
            }
        }
        finally { CloseClipboard(); }
    }

    [LibraryImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool OpenClipboard(nint owner);

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool CloseClipboard();

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool EmptyClipboard();

    [LibraryImport("user32.dll")]
    private static partial nint SetClipboardData(uint format, nint data);

    [LibraryImport("kernel32.dll")]
    private static partial nint GlobalAlloc(uint flags, nuint bytes);

    [LibraryImport("kernel32.dll")]
    private static partial nint GlobalLock(nint mem);

    [LibraryImport("kernel32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool GlobalUnlock(nint mem);

    [LibraryImport("kernel32.dll")]
    private static partial nint GlobalFree(nint mem);
}

/// <summary>Remove-AkariPaths: files and folders deleted (a path's last part may hold wildcards: everything it matches
/// goes, folders with their contents); what is in use or protected stays. The cleanup Actions' only bulk delete.</summary>
public static class SystemPaths
{
    /// <summary>How many of the matched items went.</summary>
    public static int Remove(IEnumerable<string> paths)
    {
        var n = 0;
        foreach (var p in paths)
            foreach (var item in Match(p))
            {
                try
                {
                    if (Directory.Exists(item)) DeleteFolder(item);
                    else
                    {
                        File.SetAttributes(item, FileAttributes.Normal);
                        File.Delete(item);
                    }
                    n++;
                }
                catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
            }
        return n;
    }

    // Get-Item -Path <p> -Force: the item, or every item its last part's wildcards match
    private static IEnumerable<string> Match(string path)
    {
        var name = Path.GetFileName(path);
        if (name.IndexOfAny(['*', '?']) < 0) return File.Exists(path) || Directory.Exists(path) ? [path] : [];
        var folder = Path.GetDirectoryName(path);
        if (folder is null || !Directory.Exists(folder)) return [];
        try { return Directory.EnumerateFileSystemEntries(folder, name).ToList(); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { return []; }
    }

    // Remove-Item -Recurse -Force: read-only files too; one that can't go fails the whole item, as there
    private static void DeleteFolder(string folder)
    {
        foreach (var f in Directory.EnumerateFiles(folder, "*", SearchOption.AllDirectories)) File.SetAttributes(f, FileAttributes.Normal);
        Directory.Delete(folder, recursive: true);
    }
}
