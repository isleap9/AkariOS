using AkariOS.App.Shell;
using AkariOS.App.ViewModels;
using AkariOS.App.Views;
using AkariOS.Core;
using AkariOS.Core.Presets;
using AkariOS.Framework;
using AkariOS.Framework.Navigation;
using AkariOS.Framework.Services;
using AkariOS.Tweaks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.Windows.AppLifecycle;

namespace AkariOS.App;

/// <summary>
/// The window's side of AkariOS-Native.exe (Program.Main starts it): the framework's services, the engine, the shell.
/// Errors go to akari.log (AkariLog), not the framework's file logger.
/// </summary>
public partial class App : Application
{
    private IHost? _host;
    private IAkariLog? _log;

    /// <summary>Usable from XAML bindings and non-DI code.</summary>
    public static IServiceProvider Services { get; private set; } = null!;

    public static MainWindow? MainWindow { get; private set; }

    public static string AppName => "AkariOS";

    /// <summary>One-click closed the window: Program runs this preset's phases in a console after it.</summary>
    public static Preset? OneClick { get; set; }

    public App()
    {
        InitializeComponent();
        UnhandledException += OnUnhandledException;
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        base.OnLaunched(args);

        // one window: a second launch brings the first to the front
        var main = AppInstance.FindOrRegisterForKey("AkariOS.Native");
        if (!main.IsCurrent)
        {
            main.RedirectActivationToAsync(AppInstance.GetCurrent().GetActivatedEventArgs()).GetAwaiter().GetResult();
            Environment.Exit(0);
            return;
        }
        main.Activated += (_, _) => MainWindow?.DispatcherQueue.TryEnqueue(() => MainWindow?.Activate());

        try
        {
            _host = BuildHost();
            Services = _host.Services;
            _log = Services.GetRequiredService<IAkariLog>();
            var log = _log;
            AppDomain.CurrentDomain.UnhandledException += (_, e) => log.WriteFile($"Error: {e.ExceptionObject}");
            TaskScheduler.UnobservedTaskException += (_, e) => { log.WriteFile($"Error: {e.Exception}"); e.SetObserved(); };

            // the loader's Problems: Warnings and Errors to akari.log (Write-AkariProblems)
            foreach (var p in Services.GetRequiredService<Engine>().Loaded.Problems) _log.WriteFile($"{p.Level}: {p.File}: {p.Message}");

            // Akari crimson before any brush is made; the saved choice is read just after
            Accent.Apply(Resources, Accent.Akari);
            MainWindow = Services.GetRequiredService<MainWindow>();
            MainWindow.Closed += (_, _) => Shutdown();
            MainWindow.Activate();
        }
        catch (Exception e)
        {
            // no window to show it in: akari.log and Windows' own message box (Write-AkariCrash)
            Program.Crash("AkariOS could not start", e);
            Exit();
            return;
        }

        DispatcherQueue.GetForCurrentThread().TryEnqueue(async () =>
        {
            try
            {
                var theme = Services.GetRequiredService<IThemeService>();
                await theme.InitializeAsync();
                var accent = await Services.GetRequiredService<ISettingsService>().GetAsync(Accent.Key, Accent.Akari) ?? Accent.Akari;
                if (accent != Accent.Akari) Services.GetRequiredService<AccentChoice>().Apply(accent);
                MainWindow?.ApplyTheme(theme.CurrentTheme);
                // every launch: the update check, once the window is up (on Home, an Available release asks)
                Services.GetRequiredService<UpdateService>().Check(manual: false);
                // the drift check (X3): only after Windows' build changed since the last one
                _ = Services.GetRequiredService<DriftCheck>().CheckAsync(manual: false);
                // X6: the numbers after the last Run, once Windows has settled after its restart
                _ = Services.GetRequiredService<MetricsAfter>().StartAsync();
                // a mount left by a build the app closed during: discarded in the background (Clear-AkariIsoLeftover)
                if (Services.GetRequiredService<IsoTools>().Build is { } iso)
                    _ = Task.Run(() =>
                    {
                        try { iso.ClearLeftover(); }
                        catch (Exception e) { _log?.WriteFile($"Error: ISO Builder: leftover not cleared: {e.Message}"); }
                    });
            }
            catch (Exception e)
            {
                _log?.WriteFile($"Error: starting: {e}");
            }
        });
    }

    private static IHost BuildHost()
    {
        var builder = Host.CreateApplicationBuilder();
        builder.Logging.ClearProviders();
        builder.Logging.AddDebug();

        Register(builder.Services, DispatcherQueue.GetForCurrentThread());
        return builder.Build();
    }

    /// <summary>The app's services (BuildHost; the tests resolve the view models through it, the window and the engine
    /// replaced). Queue: the UI thread's.</summary>
    public static void Register(IServiceCollection services, DispatcherQueue? queue)
    {
        services.AddMvvmFramework();
        // %LOCALAPPDATA%\AkariOS.Native\settings.json (AkariPaths.UserFolder)
        services.AddSingleton<ISettingsStorage>(new FileSettingsStorage("AkariOS.Native"));

        services.AddSingleton<IAkariLog>(new AkariLog(AkariPaths.LogFile));
        services.AddSingleton(sp => Engine.Live(TweaksAssembly.Codes, sp.GetRequiredService<IAkariLog>()));

        services.AddSingleton<IShellOpen, ShellOpen>();
        services.AddSingleton(sp => new ActivityLog(ActivityLog.Default, sp.GetRequiredService<IAkariLog>()));
        services.AddSingleton<HomeStats>();
        services.AddSingleton<IFilePicker>(_ => new WindowFilePicker(() => MainWindow!.AppWindow.Id));
        services.AddSingleton(sp => UpdateService.Live(sp.GetRequiredService<IBackground>(), sp.GetRequiredService<IDialogService>(),
            sp.GetRequiredService<ShellState>(), sp.GetRequiredService<CatalogueViewModel>(), sp.GetRequiredService<IAkariLog>(),
            () => MainWindow?.Close()));
        // the accent: Akari until settings.json says otherwise (OnLaunched); a change refreshes the window's theme
        services.AddSingleton(_ => new AccentChoice(Accent.Akari, a =>
        {
            Accent.Apply(Current.Resources, a);
            MainWindow?.RefreshTheme();
        }));
        // made on the UI thread (OnLaunched): the window's dispatcher queue
        services.AddSingleton<IBackground>(new DispatcherBackground(queue!));
        services.AddSingleton<ShellState>();
        // Akari's dialogs over the framework's own (registered last, so it wins)
        services.AddSingleton<IDialogService>(_ => new AkariDialogs(() => MainWindow?.Content?.XamlRoot));
        services.AddSingleton<ClosingGuard>();
        services.AddSingleton<SearchTip>();
        services.AddSingleton<RestoreRule>();
        services.AddSingleton<CatalogueViewModel>();
        services.AddSingleton<ServicesListViewModel>();
        services.AddSingleton<TasksListViewModel>();
        services.AddSingleton<StartupListViewModel>();
        services.AddSingleton<GamesListViewModel>();
        services.AddSingleton<DriftCheck>();
        services.AddSingleton<MetricsAfter>();
        services.AddTransient<CataloguePageViewModel>();
        services.AddSingleton(_ => new AppIcons(AssetFiles.Default));
        services.AddSingleton<InstallViewModel>();
        services.AddSingleton<RemoveAppsViewModel>();
        services.AddSingleton<DownloadsViewModel>();
        // Install USB: this PC's drives and language (guarded: tests give their own)
        services.AddSingleton<Core.Unattend.ISetupDrives>(_ => new Core.Unattend.LiveSetupDrives());
        services.AddSingleton<Core.Unattend.IPcRegion>(sp => Core.Unattend.RegistryPcRegion.Live(sp.GetRequiredService<Engine>().Registry));
        services.AddSingleton<UnattendViewModel>();
        // the ISO Builder: DISM, the hives, the ISO drive, UUP Dump and Massgrave (guarded: tests give their own)
        services.AddSingleton(sp => IsoTools.Live(sp.GetRequiredService<Engine>()));
        services.AddSingleton<ITimers>(new DispatcherTimers(queue!));
        services.AddSingleton<IsoBuilderViewModel>();
        services.AddSingleton<ITextDialog>(_ => new ContentTextDialog(() => MainWindow?.Content?.XamlRoot));
        services.AddSingleton<IChoiceDialog>(_ => new ContentChoiceDialog(() => MainWindow?.Content?.XamlRoot));
        // One-click: Program runs the preset in a console once the window has closed
        services.AddSingleton(_ => new OneClickHandoff(p =>
        {
            OneClick = p;
            MainWindow?.CloseForOneClick();
        }));

        services.AddSingleton<MainWindow>();
        // never the window through DI (see WindowNavigator): it is still being made when Home's view model needs one
        services.AddSingleton<IShellNavigator>(new WindowNavigator(() => MainWindow));
        services.AddTransient<HomeViewModel>();
        services.AddTransient<OptimizeViewModel>();
        services.AddTransient<SettingsViewModel>();
        services.AddTransient<PlaceholderViewModel>();

        // pages are made through the container
        services.AddSingleton<INavigationService>(sp =>
            new FrameNavigationService(type => (Page)ActivatorUtilities.CreateInstance(sp, type)));
        services.AddSingleton(_ => new Func<XamlRoot?>(() => MainWindow?.Content?.XamlRoot));
        services.AddSingleton(_ => new Func<IntPtr>(() =>
            MainWindow is null ? IntPtr.Zero : WinRT.Interop.WindowNative.GetWindowHandle(MainWindow)));
    }

    // an error inside a click: in akari.log and a message, instead of closing the app
    private void OnUnhandledException(object sender, Microsoft.UI.Xaml.UnhandledExceptionEventArgs e)
    {
        // WinUI's own errors carry no stack trace: the window's state and last steps say where it happened
        _log?.WriteFile($"Error: UI: {e.Exception} (HRESULT 0x{e.Exception.HResult:X8}; {MainWindow?.Describe() ?? "no window"})");
        if (MainWindow?.Content?.XamlRoot is null) return;
        e.Handled = true;
        var message = e.Exception.Message;
        DispatcherQueue.GetForCurrentThread().TryEnqueue(async () =>
        {
            try
            {
                await Services.GetRequiredService<IDialogService>()
                    .ShowErrorAsync("Something went wrong", $"{message}{Environment.NewLine}{Environment.NewLine}The details are in akari.log.");
            }
            catch
            {
                // never back into this handler from its own dialog
            }
        });
    }

    private void Shutdown()
    {
        try { _host?.Dispose(); }
        catch
        {
            // a failing Dispose never keeps the app open
        }
        _host = null;
        Exit();
    }
}
