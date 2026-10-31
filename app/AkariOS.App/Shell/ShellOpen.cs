using System.Diagnostics;
using System.IO;
using AkariOS.Core;

namespace AkariOS.App.Shell;

/// <summary>What the app opens outside itself: a web page, a folder, a Windows program (System Restore).</summary>
public interface IShellOpen
{
    void Url(string url);
    void Folder(string path);
    void Program(string path);
}

/// <summary>The real one, through the shell (guarded: tests use a fake that only records).</summary>
public sealed class ShellOpen : IShellOpen
{
    public ShellOpen() => SystemGuard.Check("Opening links and programs");

    public void Url(string url)
    {
        if (!Uri.TryCreate(url, UriKind.Absolute, out var u) || u.Scheme is not ("https" or "http")) return;
        Process.Start(new ProcessStartInfo(u.AbsoluteUri) { UseShellExecute = true })?.Dispose();
    }

    public void Folder(string path)
    {
        if (Directory.Exists(path)) Process.Start(new ProcessStartInfo("explorer.exe", $"\"{path}\"") { UseShellExecute = true })?.Dispose();
    }

    public void Program(string path) => Process.Start(new ProcessStartInfo(path) { UseShellExecute = true })?.Dispose();
}
