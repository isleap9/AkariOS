using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Tools.Cleanup;

/// <summary>src/Tweaks/Tools/Cleanup/TempFiles.ps1 (ZOICWARE): Windows' Temp folder and the real user's, emptied. An
/// Action: nothing to put back.</summary>
[TweakCode("cleanup-temp-files")]
public sealed class TempFiles : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var n = SystemPaths.Remove([PortableTool.Temp(c, "*"), Path.Combine(FileData.UserFolder(c, "Local AppData"), "Temp", "*")]);
        c.Log.Write($"Deleted {n} temporary files and folders");
    }
}
