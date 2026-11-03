using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Privacy;

/// <summary>src/Tweaks/Optimize/Privacy/AppPermissions.ps1's After, both ways: Windows keeps its own copy of the
/// choices, so the capability access service stops and that copy (CapabilityConsentStorage.db*, TrustedInstaller's)
/// is deleted; Windows builds it again from the values. Neither failing stops the Tweak, as in the PowerShell app.</summary>
[TweakCode("privacy-app-permissions")]
public sealed class AppPermissions : ITweakCode
{
    public void After(Tweak tweak, TweakContext c, TweakMode mode)
    {
        var s = c.Services;
        if (s.ProgramData.Length == 0) throw new NotSupportedException("this engine has no ProgramData folder");
        if (!FileData.Need(s.Services, "service control").Stop("camsvc")) c.Log.Write("Warning: camsvc did not stop");
        var dir = Path.Combine(s.ProgramData, "Microsoft", "Windows", "CapabilityAccessManager");
        FileData.Need(s.Trusted, "TrustedInstaller").Run(() =>
        {
            if (!Directory.Exists(dir)) return;
            foreach (var f in Directory.GetFiles(dir, "CapabilityConsentStorage.db*"))
            {
                try { File.Delete(f); }
                catch (Exception e) when (e is IOException or UnauthorizedAccessException) { c.Log.Write($"Warning: {Path.GetFileName(f)} not deleted ({e.Message})"); }
            }
        });
    }
}
