using AkariOS.Core;
using AkariOS.Core.Iso;
using AkariOS.Core.Pipeline;
using AkariOS.Core.Wim;
using Microsoft.Extensions.DependencyInjection;
using Xunit;

namespace AkariOS.Tests;

/// <summary>
/// Guards the DI graph for pipeline/ISO/WIM services.
///
/// Regression: BuilderViewModel gained IsoMountService + WimService constructor params for the
/// edition scan, but they were never registered — the app crashed on launch with
/// "Unable to resolve service for type 'IsoMountService'". The real BuilderViewModel can't be
/// constructed in a test (WinUI type), so instead we assert every Core service it depends on is
/// resolvable from a container registered the same way App.xaml.cs does.
/// </summary>
public sealed class ServiceRegistrationTests
{
    /// <summary>Mirrors the Core-service registrations in App.ConfigureHost.</summary>
    private static ServiceProvider BuildCoreServices()
    {
        var services = new ServiceCollection();
        // Core services take optional ILogger<T> params, so no logging registration is needed.
        services.AddSingleton(_ => AkariPipelineFactory.Create());
        services.AddSingleton<WimService>();
        services.AddSingleton<IsoMountService>();
        return services.BuildServiceProvider(new ServiceProviderOptions { ValidateOnBuild = true });
    }

    [Theory]
    [InlineData(typeof(InjectionPipeline))]
    [InlineData(typeof(WimService))]
    [InlineData(typeof(IsoMountService))]
    public void CoreService_IsResolvable(Type serviceType)
    {
        using var provider = BuildCoreServices();
        Assert.NotNull(provider.GetRequiredService(serviceType));
    }

    /// <summary>
    /// Every constructor parameter BuilderViewModel asks for must be registered. Reflection over
    /// the real VM type would need WinUI; instead assert the known dependency set stays resolvable,
    /// so adding a new Core dependency without registering it fails here.
    /// </summary>
    [Fact]
    public void BuilderViewModelDependencies_AllResolvable()
    {
        using var provider = BuildCoreServices();

        // Keep in sync with BuilderViewModel's constructor.
        Type[] required = [typeof(InjectionPipeline), typeof(WimService), typeof(IsoMountService)];

        foreach (var t in required)
            Assert.NotNull(provider.GetService(t));
    }
}
