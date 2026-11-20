using AkariOS.App.Shell;
using AkariOS.App.ViewModels;
using AkariOS.Core;
using Microsoft.Extensions.DependencyInjection;

namespace AkariOS.App.Tests;

/// <summary>
/// The app's DI registrations (App.Register): every view model resolves without the window. The window's constructor
/// opens Home; a view model that reached the window through DI made a second window, which opened Home again, until
/// the stack overflowed and the app closed before showing anything. Here the window throws when resolved.
/// </summary>
public sealed class ServicesWiringTests : IDisposable
{
    private readonly AppHarness _h = new();

    public void Dispose() => _h.Dispose();

    private ServiceProvider Provider(AppTest t)
    {
        var services = new ServiceCollection();
        App.Register(services, null);
        // the window can't be made in a test host: resolving it fails the test
        services.AddSingleton<MainWindow>(_ => throw new InvalidOperationException("a view model reached the window through DI"));
        // the test's engine (the live one is guarded) and background
        services.AddSingleton(t.Engine);
        services.AddSingleton<IBackground>(t.Work);
        services.AddSingleton<IShellOpen>(new NoOpen());
        // the guarded ones: the test's
        services.AddSingleton<IFilePicker>(t.Picker);
        services.AddSingleton(t.Updates);
        services.AddSingleton(t.Activity);
        services.AddSingleton<Core.Unattend.ISetupDrives>(t.Drives);
        services.AddSingleton<Core.Unattend.IPcRegion>(t.Region);
        return services.BuildServiceProvider();
    }

    private sealed class NoOpen : IShellOpen
    {
        public void Url(string url) { }
        public void Folder(string path) { }
        public void Program(string path) { }
    }

    // made by another view model, never through DI: a card, Install AkariOS' steps and their parts
    private static readonly Type[] Parts = [typeof(TweakCardViewModel), typeof(TweaksStepViewModel), typeof(AppsStepViewModel), typeof(TweakSectionViewModel),
        typeof(TweakCategoryViewModel), typeof(AppTableViewModel), typeof(RunItemViewModel), typeof(AppCardViewModel), typeof(UaSectionViewModel)];

    [Fact]
    public void Every_view_model_resolves_without_the_window()
    {
        using var sp = Provider(_h.Make(AppHarness.Fixtures()));
        foreach (var type in typeof(App).Assembly.GetTypes().Where(t => t.Namespace == "AkariOS.App.ViewModels" && t.Name.EndsWith("ViewModel", StringComparison.Ordinal)
                     && !t.Name.Contains("Row", StringComparison.Ordinal) && !Parts.Contains(t)))
            Assert.NotNull(sp.GetRequiredService(type));
    }

    [Fact]
    public void Home_opens_pages_through_the_window_once_it_exists()
    {
        using var sp = Provider(_h.Make(AppHarness.Fixtures()));
        // no window yet: nothing happens, nothing throws
        sp.GetRequiredService<HomeViewModel>().OptimizeCommand.Execute(null);
        Assert.IsType<WindowNavigator>(sp.GetRequiredService<IShellNavigator>());
    }
}
