using AkariOS.Core.Apps;
using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Advanced.Features;

/// <summary>src/Tweaks/Advanced/Features/OpenSshServer.ps1 (winutil's Invoke-WinUtilSSHServer): the capability (through
/// Windows Update, turned on for it when off), sshd and ssh-agent started with Windows, administrators_authorized_keys
/// for Administrators and SYSTEM only. Revert removes the capability and puts ssh-agent back off; the keys file stays.</summary>
[TweakCode("features-openssh-server")]
public sealed class OpenSshServer : ITweakCode
{
    private const string Capability = "OpenSSH.Server~~~~0.0.1.0";

    private static AppPackages Dism(TweakContext c) => TweakServices.Need(c.Services.Apps, "DISM");
    private static IServiceManager Services(TweakContext c) => TweakServices.Need(c.Services.Services, "service manager");

    public TweakState Detect(Tweak tweak, TweakContext c) => Dism(c).CapabilityState(Capability) switch
    {
        null => TweakState.Unknown,
        var s when s.Equals("Installed", StringComparison.OrdinalIgnoreCase) => TweakState.Optimized,
        _ => TweakState.Default,
    };

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var s = Dism(c).CapabilityState(Capability) ?? throw new InvalidOperationException("this Windows has no OpenSSH Server");
        if (!s.Equals("Installed", StringComparison.OrdinalIgnoreCase))
        {
            c.Log.Write("Adding OpenSSH Server (it takes a while)");
            FeatureToggle.UseWindowsUpdate(c, () => Dism(c).AddCapability(Capability), "Connect to the internet and try again");
        }
        foreach (var n in new[] { "sshd", "ssh-agent" })
        {
            if (Services(c).One(n) is null) { c.Log.Write($"OpenSSH Server: no {n} service, skipped"); continue; }
            ServiceStart.Set(c.Registry, n, "Automatic");
            Services(c).Control(n, "Start");
        }
        var keys = Path.Combine(TweakServices.Folder(c.Services.ProgramData, "ProgramData"), "ssh", "administrators_authorized_keys");
        TweakServices.Need(c.Services.Acl, "file permissions").AdminsOnly(keys);
        c.Log.Write($"OpenSSH Server: on. Administrators' public keys go in {keys}");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        if (string.Equals(Dism(c).CapabilityState(Capability), "Installed", StringComparison.OrdinalIgnoreCase))
        {
            if (Services(c).One("sshd") is not null) Services(c).Control("sshd", "Stop");
            c.Log.Write("Removing OpenSSH Server");
            Dism(c).RemoveCapability(Capability);
        }
        if (Services(c).One("ssh-agent") is not null)
        {
            Services(c).Control("ssh-agent", "Stop");
            ServiceStart.Set(c.Registry, "ssh-agent", "Disabled");
        }
    }
}
