using System.IO;
using System.Runtime.InteropServices;
using System.Windows;
using AkariOS.Core;
using AkariOS.Core.Machine;
using AkariOS.Core.Update;
using AkariOS.Tweaks;

namespace AkariOS.App;

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

        var appLog = new AkariLog(AkariPaths.LogFile);
        // after an update: the old exe (still closing) and a stray download go
        if (Environment.ProcessPath is { } exePath) Task.Run(() => Updater.Cleanup(exePath));
        // the exe copy a finished Run in phases resumed from
        Task.Run(() => Core.Runs.SelfCopy.Live().Clean(File.Exists(Core.Runs.RunStore.Default)));
        var engine = Engine.Live(TweaksAssembly.Codes, appLog);
        var app = new Application { ShutdownMode = ShutdownMode.OnMainWindowClose };
        var motion = AkariXaml.MotionOn();
        Look.Motion.Initialize(motion);
        Look.Motion.HookSegmentPills();
        foreach (var d in AkariXaml.SharedResources("Dark", motion))
            app.Resources.MergedDictionaries.Add(d);
        Look.Assets.AddFonts(app.Resources);
        // System follows the real user's app mode (rule 6: their hive, not the elevated account's)
        var theme = new Look.ThemeService(app.Resources, new Look.SettingsFile(Path.Combine(AkariPaths.UserFolder, "settings.json")),
            () => engine.Registry.GetValue(@"HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme") is uint v ? (int)v : null,
            motion);
        theme.Apply(theme.Saved());
        var shell = new Shell.ShellViewModel(AkariInfo.Version, Core.Tweaks.Catalogue.Pages(Core.Tweaks.Catalogue.Tweaks(engine.Loaded.Tweaks, engine.System)));
        var services = new Shell.AppServices { Engine = engine, Shell = shell, Theme = theme, Open = new Shell.ShellOpen(), Log = appLog, Picker = new Shell.FilePicker(),
            Drives = new Core.Unattend.LiveSetupDrives(), Region = Core.Unattend.RegistryPcRegion.Live(engine.Registry) };
        // the ISO Builder: DISM, the hives, the ISO drive, UUP Dump and Massgrave on the engine's parts; AkariOS in an
        // image is this exe (none for a developer build); a mount left by a closed build is discarded in the background
        var tw = engine.Services;
        services.IsoBuild = new Core.Iso.IsoBuild(Core.Iso.IsoParts.Live(engine.Files, engine.Registry, tw.Trusted!, tw.Exe!, tw.Http!, tw.Shortcuts!, appLog));
        services.IsoDownload = new Core.Iso.IsoDownload(Core.Iso.IsoDownloadParts.Live(tw.Http!, tw.Exe!, appLog, engine.Registry));
        services.AkariExe = Shell.UpdateService.IsDeveloperBuild() ? null : Environment.ProcessPath;
        var isoBuild = services.IsoBuild;
        Task.Run(isoBuild.ClearLeftover);
        var window = new MainWindow(theme, shell, Pages.PageFactory.For(services));
        services.Dialogs = Shell.Dialogs.For(window, appLog);
        services.Bars = window.CatBars;
        services.Footer = new Pages.StepFooter(window.StepFooter, window.StepBack, window.StepDots, window.StepNext);
        services.Install?.Attach(services.Footer);
        // a Run or a change running, Safe Mode changes waiting: closing asks first (not for an update: the new exe
        // is starting already, and the update is only offered with nothing running or waiting)
        var updating = false;
        window.Closing += (s, e) =>
        {
            if (updating) return;
            if (services.Install?.CanClose() == false || services.Iso?.CanClose() == false) { e.Cancel = true; return; }
            services.Catalogue?.OnClosing(s, e);
        };
        services.Close = () => { updating = true; window.Close(); };
        services.Updates = Shell.UpdateService.Live(new ExeRunner(), appLog);
        // every launch: checked in the background once the window is up
        window.Loaded += (_, _) => services.Updates.Check(services, manual: false);
        Shell.OptionsMenu.Attach(window.MenuBtn, Shell.OptionsMenu.Build(services));
        foreach (var p in engine.Loaded.Problems) appLog.WriteFile($"{p.Level}: {p.File}: {p.Message}");
        // an error inside a click: in akari.log and a message, instead of closing the app
        app.DispatcherUnhandledException += (_, e) =>
        {
            e.Handled = true;
            appLog.WriteFile($"Error: UI: {e.Exception}");
            services.Dialogs.Message($"Something went wrong: {e.Exception.Message}\n\nThe details are in akari.log.", "Error");
            shell.SetBusy(false);
        };
        var code = app.Run(window);
        // One-click closed the window: its console runs the AkariOS preset's phases (a fresh engine, its log printed)
        if (services.OneClick is { } preset)
            return InConsole((console, log) => console.OneClick(Engine.Live(TweaksAssembly.Codes, log), preset));
        return code;
    }
}
