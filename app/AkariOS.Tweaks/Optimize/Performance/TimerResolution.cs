using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Performance;

/// <summary>
/// src/Tweaks/Optimize/Performance/TimerResolution.ps1: the "Set Timer Resolution Service", compiled from
/// src/OneClick/settimerresolutionservice.cs with the .NET Framework compiler (Invoke-AkariCsc; the source written out
/// to the Files folder first), installed to start automatically and started, plus GlobalTimerResolutionRequests so it
/// applies to every process on Windows 11. Optimized while the service starts automatically; Revert removes it all.
/// </summary>
[TweakCode("performance-timer-resolution")]
public sealed class TimerResolution : ITweakCode
{
    public const string Service = "Set Timer Resolution Service";
    public const string Source = "src/OneClick/settimerresolutionservice.cs";
    private const string Kernel = @"HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel";

    private static string Exe(TweakContext c) => Path.Combine(TweakServices.Folder(c.Services.Windows, "Windows"), "SetTimerResolutionService.exe");

    public TweakState Detect(Tweak tweak, TweakContext c) => FileData.Need(c.Services.Services, "service control").StartType(Service) switch
    {
        null => TweakState.Default,
        "Automatic" => TweakState.Optimized,
        _ => TweakState.Custom,
    };

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var s = c.Services;
        var services = FileData.Need(s.Services, "service control");
        if (services.StartType(Service) is not null)
        {
            services.Stop(Service);
            services.Delete(Service);
            s.Sleep(TimeSpan.FromSeconds(2));
        }
        var exe = Exe(c);
        Compile(c, exe);
        services.Create(Service, exe, automatic: true);
        services.Start(Service);
        c.Registry.SetValue(Kernel, "GlobalTimerResolutionRequests", 1, "DWord");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        var s = c.Services;
        var services = FileData.Need(s.Services, "service control");
        services.Stop(Service);
        if (services.StartType(Service) is not null) services.Delete(Service);
        s.Sleep(TimeSpan.FromSeconds(2));
        try { File.Delete(Exe(c)); }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { c.Log.Write($"Warning: {Exe(c)} not deleted ({e.Message})"); }
        c.Registry.RemoveValue(Kernel, "GlobalTimerResolutionRequests");
    }

    // Invoke-AkariCsc: the .NET Framework compiler; no exe after it = failed, with what it said
    private static void Compile(TweakContext c, string exe)
    {
        var s = c.Services;
        var folder = TweakServices.Folder(s.FilesFolder, "Files");
        Directory.CreateDirectory(folder);
        var src = Path.Combine(folder, Path.GetFileName(Source));
        File.WriteAllBytes(src, c.Files.ReadBytes(Source));
        var csc = Path.Combine(TweakServices.Folder(s.Windows, "Windows"), @"Microsoft.NET\Framework64\v4.0.30319\csc.exe");
        var r = FileData.Need(s.Exe, "program runner").Run(csc, $"-nologo \"-out:{exe}\" \"{src}\"");
        if (r.ExitCode != 0 || !File.Exists(exe)) throw new InvalidOperationException($"csc failed: {r.Output.Trim()}");
    }
}
