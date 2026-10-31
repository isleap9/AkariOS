using System.IO;
using System.Runtime.InteropServices;
using System.Windows;
using AkariOS.Core;
using AkariOS.Tweaks;

namespace AkariOS.App;

public static partial class Program
{
    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool AttachConsole(int processId);

    [STAThread]
    public static int Main(string[] args)
    {
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
        var shell = new Shell.ShellViewModel(AkariInfo.Version);
        var services = new Shell.AppServices { Engine = engine, Shell = shell, Theme = theme, Open = new Shell.ShellOpen(), Log = appLog };
        var window = new MainWindow(theme, shell, Pages.PageFactory.For(services));
        services.Dialogs = Shell.Dialogs.For(window, appLog);
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
        return app.Run(window);
    }
}
