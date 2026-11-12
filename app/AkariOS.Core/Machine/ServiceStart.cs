using System.Security;
using AkariOS.Core.Registry;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Machine;

/// <summary>
/// Set-AkariServiceStart: a service's startup type in its registry key (Start, DelayedAutostart), and its template's
/// for a per-user instance (Windows makes each user's instance from it at sign-in): as admin, else every row as
/// TrustedInstaller (many service keys are protected); fails when Windows keeps the old one (Defender's change only in
/// Safe Mode). Takes effect at the service's next start. The registry engine's paths, so tests use a test key.
/// </summary>
public static class ServiceStart
{
    /// <summary>$AkariServicesRoot.</summary>
    public const string Root = @"HKLM:\SYSTEM\CurrentControlSet\Services";

    public static void Set(RegistryEngine reg, string name, string startType)
    {
        var (start, delayed) = ServiceLists.StartValue(startType);
        var names = new[] { name, ServiceLists.Template(name) }.Where(n => n.Length > 0 && reg.KeyExists($@"{Root}\{n}")).ToList();
        if (names.Count == 0) throw new InvalidOperationException($"no service named {name}");
        var rows = names.SelectMany(n => new[]
        {
            new RegistryRow($@"{Root}\{n}", "Start", "DWord", start, OsValue.Both(start), false),
            new RegistryRow($@"{Root}\{n}", "DelayedAutostart", "DWord", delayed, OsValue.Both(delayed), false),
        }).ToList();
        try { foreach (var r in rows) reg.SetValue(r.Path, r.Name!, r.Value!, "DWord"); }
        catch (Exception e) when (e is UnauthorizedAccessException or SecurityException or IOException) { reg.Invoke(rows, TweakMode.Apply, 0, asTrusted: true); }
        foreach (var n in names)
            if (!RegistryEngine.Matches(reg.GetValue($@"{Root}\{n}", "Start"), start))
                throw new InvalidOperationException($"Windows keeps the startup type of {n} (a protected service: some change only in Safe Mode)");
    }
}
