using AkariOS.Core.Apps;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Remove;

// Steps the legacy app removals share (src/Tweaks/Apps/Remove/*.ps1, FR33THY's legacy apps).

/// <summary>Done when no product like the pattern is left (Get-AkariMsi).</summary>
internal static class Msi
{
    public static TweakState Done(TweakContext c, string like) => AppSetup.Msi(c, like).Count == 0 ? TweakState.Optimized : TweakState.Default;
}

/// <summary>A System32 tool that uninstalls itself (Invoke-AkariSelfUninstall); done when its exe is gone.</summary>
internal static class SelfUninstalling
{
    private static string Exe(TweakContext c, string file) => Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "System32", file);
    public static TweakState Done(TweakContext c, string file) => File.Exists(Exe(c, file)) ? TweakState.Default : TweakState.Optimized;
    public static void Run(TweakContext c, string file, string process) => AppSetup.SelfUninstall(c, Exe(c, file), process);
}

/// <summary>Scheduled tasks by name, unregistered (Unregister-ScheduledTask).</summary>
internal static class Tasks
{
    public static void Unregister(TweakContext c, Func<string, bool> name)
    {
        var tasks = TweakServices.Need(c.Services.Tasks, "task scheduler");
        foreach (var t in tasks.Find(name)) tasks.Unregister(t);
    }
}

/// <summary>Remove-Item -Recurse -Force -ErrorAction SilentlyContinue: a file or folder, gone if it can go.</summary>
internal static class Files
{
    public static void Delete(string path)
    {
        try
        {
            if (Directory.Exists(path)) Directory.Delete(path, recursive: true);
            else if (File.Exists(path)) File.Delete(path);
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
    }
}
