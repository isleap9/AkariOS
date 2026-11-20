using System.Runtime.InteropServices;
using AkariOS.Core;
using AkariOS.Core.Machine;
using AkariOS.Core.Update;
using AkariOS.Tweaks;
using Microsoft.UI.Dispatching;

namespace AkariOS.App;

/// <summary>
/// AkariOS-Native.exe's entry point: --resume and the CLI run in a console before any XAML is loaded; else the WinUI 3
/// window (App); after it closes for One-click, the AkariOS preset's Run in a console of its own.
/// </summary>
public static partial class Program
{
    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool AttachConsole(int processId);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool AllocConsole();

    [LibraryImport("kernel32.dll")]
    private static partial IntPtr GetConsoleWindow();

    [LibraryImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool ShowWindow(IntPtr window, int show);

    [LibraryImport("user32.dll", EntryPoint = "MessageBoxW", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int MessageBox(IntPtr owner, string text, string caption, uint type);

    /// <summary>
    /// A failure before or while the window starts (Write-AkariCrash): akari.log, then Windows' own message box (no
    /// XAML: it may be what failed). Never throws.
    /// </summary>
    public static void Crash(string what, Exception e)
    {
        try { new AkariLog(AkariPaths.LogFile).WriteFile($"Error: {what}: {e}"); }
        catch (Exception)
        {
            // the message box still says what happened
        }
        // MB_OK | MB_ICONERROR
        MessageBox(IntPtr.Zero, $"{what}: {e.Message}\n\nThe details are in {AkariPaths.LogFile}.", "AkariOS", 0x10);
    }

    /// <summary>
    /// A Run in phases in a console window of its own, maximized (Akari.ps1's -Resume and One-click consoles): the log's
    /// live lines printed, an error in akari.log and on screen, waiting for Enter so it can be read.
    /// </summary>
    private static int InConsole(Func<RunConsole, AkariLog, int> body)
    {
        AllocConsole();
        ShowWindow(GetConsoleWindow(), 3);
        var output = new StreamWriter(Console.OpenStandardOutput()) { AutoFlush = true };
        var input = new StreamReader(Console.OpenStandardInput());
        var log = new AkariLog(AkariPaths.LogFile);
        log.Line += output.WriteLine;
        try { return body(new RunConsole(output, input, new RealConsole()), log); }
        catch (Exception e)
        {
            log.WriteFile($"Error: {e}");
            output.WriteLine($"AkariOS stopped: {e.Message}");
            output.WriteLine("The details are in akari.log. Press Enter to close this window.");
            input.ReadLine();
            return 1;
        }
    }

    [STAThread]
    public static int Main(string[] args)
    {
        // RunOnce after a restart: the saved Run goes on for the user it started for
        if (Cli.IsResume(args))
            return InConsole((console, log) => console.Resume(new Core.Runs.RunStore(Core.Runs.RunStore.Default, () => { }).Get,
                sid => Engine.Live(TweaksAssembly.Codes, log, sid)));

        if (Cli.IsCli(args))
        {
            // a WinExe has no console: write to the one it was started from
            AttachConsole(-1);
            var output = new StreamWriter(Console.OpenStandardOutput()) { AutoFlush = true };
            var error = new StreamWriter(Console.OpenStandardError()) { AutoFlush = true };
            // the Outcome lines are the CLI's output: the per-Tweak log lines are not repeated (as in Akari.ps1)
            var log = new AkariLog(AkariPaths.LogFile);
            log.Line += _ => { };
            return Cli.Run(args, output, error, () => Engine.Live(TweaksAssembly.Codes, log));
        }

        // after an update: the old exe (still closing) and a stray download go
        if (Environment.ProcessPath is { } exePath) Task.Run(() => Updater.Cleanup(exePath));
        // the exe copy a finished Run in phases resumed from
        Task.Run(() => Core.Runs.SelfCopy.Live().Clean(File.Exists(Core.Runs.RunStore.Default)));

        try
        {
            WinRT.ComWrappersSupport.InitializeComWrappers();
            Microsoft.UI.Xaml.Application.Start(p =>
            {
                SynchronizationContext.SetSynchronizationContext(new DispatcherQueueSynchronizationContext(DispatcherQueue.GetForCurrentThread()));
                _ = new App();
            });
        }
        catch (Exception e)
        {
            // WinUI itself didn't start (the Windows App SDK's files, an old Windows)
            Crash("AkariOS could not start", e);
            return 1;
        }

        // One-click closed the window: its console runs the AkariOS preset's phases (a fresh engine, its log printed)
        if (App.OneClick is { } preset)
            return InConsole((console, log) => console.OneClick(Engine.Live(TweaksAssembly.Codes, log), preset));
        return 0;
    }
}
