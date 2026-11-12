using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Cleanup;

/// <summary>src/Tweaks/Tools/Cleanup/NvidiaShaderCache.ps1 (ZOICWARE): the real user's NVIDIA OpenGL and DirectX shader
/// caches. An Action: games rebuild them.</summary>
[TweakCode("cleanup-nvidia-shader-cache")]
public sealed class NvidiaShaderCache : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var local = FileData.UserFolder(c, "Local AppData");
        var low = Path.Combine(Path.GetDirectoryName(local)!, "LocalLow");
        var n = SystemPaths.Remove([Path.Combine(local, @"NVIDIA\GLCache"), Path.Combine(low, @"NVIDIA\PerDriverVersion\DXCache")]);
        c.Log.Write($"Deleted {n} shader caches");
    }
}
