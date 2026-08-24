using AkariOS.Core.Inject;
using AkariOS.Core.Iso;
using AkariOS.Core.Pipeline;
using Microsoft.Extensions.Logging;

namespace AkariOS.Core;

/// <summary>Default AkariOS build pipeline: mount → stage → inject → rebuild → cleanup.</summary>
public static class AkariPipelineFactory
{
    /// <summary>Payload files shipped with the app (copied to output dir at build time).</summary>
    public static readonly string[] DefaultPayload =
    {
        Path.Combine(AppContext.BaseDirectory, "assets", "WinSux", "WinSux.ps1"),
    };

    public static InjectionPipeline Create(
        ILogger<AkariOS.Core.Pipeline.InjectionPipeline>? pipelineLogger = null,
        ILogger<IsoMountService>? mountLogger = null,
        ILogger<OscdimgService>? oscdimgLogger = null)
    {
        var mountService = new IsoMountService(mountLogger);

        IBuildStep[] steps =
        [
            new MountStep(mountService),
            new StagingStep(),
            new OemInjectStep(),
            new IsoRebuildStep(new OscdimgService(oscdimgLogger)),
            // Cleanup steps run last; they never fail the build.
            new DismountStep(mountService),
            new StagingCleanupStep(),
        ];

        return new InjectionPipeline(steps, pipelineLogger);
    }
}
