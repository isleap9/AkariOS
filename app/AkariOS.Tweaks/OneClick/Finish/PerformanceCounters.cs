using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.OneClick.Finish;

/// <summary>src/Tweaks/OneClick/Finish/PerformanceCounters.ps1: lodctr /R, 64- and 32-bit, where each is. An Action:
/// it rebuilds them from Windows' own files.</summary>
[TweakCode("oneclick-performance-counters")]
public sealed class PerformanceCounters : ITweakCode
{
    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var windows = TweakServices.Folder(c.Services.Windows, "Windows");
        foreach (var d in new[] { "System32", "SysWOW64" })
        {
            var lodctr = Path.Combine(windows, d, "lodctr.exe");
            if (File.Exists(lodctr)) TweakServices.Need(c.Services.Exe, "program runner").Run(lodctr, "/R");
        }
    }
}
