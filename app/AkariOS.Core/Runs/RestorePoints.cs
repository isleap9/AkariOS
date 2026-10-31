using System.Management;
using AkariOS.Core.Registry;

namespace AkariOS.Core.Runs;

/// <summary>A restore point Akari made (described AkariOS, or Akari before Oct 2026).</summary>
public sealed record RestorePoint(string Description, DateTime? Date, uint Sequence);

public sealed record RestoreResult(bool Ok, string Message);

/// <summary>System Restore itself: the only reads and writes of it. The real one is <see cref="WmiSystemRestore"/>.</summary>
public interface ISystemRestore
{
    /// <summary>Every restore point on the PC.</summary>
    IReadOnlyList<RestorePoint> List();

    /// <summary>Asks Windows for a restore point; throws when it refuses.</summary>
    void Create(string description);

    /// <summary>Turns System Protection on for the system drive.</summary>
    void EnableProtection();
}

/// <summary>
/// Restore points (src/Core/Restore.ps1). Create never throws: when Windows refuses (System Protection off, or one
/// was made in the last 24 hours, which Windows skips without an error), it turns protection on, lifts the 24 hour
/// throttle for one more try and puts the throttle back.
/// </summary>
public sealed class RestorePoints(ISystemRestore restore, RegistryEngine registry, IAkariLog log)
{
    public const string Key = @"HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore";
    public const string Throttle = "SystemRestorePointCreationFrequency";

    /// <summary>The newest one Akari made, or null (Get-AkariRestorePoint).</summary>
    public RestorePoint? Latest()
    {
        try
        {
            return restore.List().Where(p => p.Description.StartsWith("Akari", StringComparison.OrdinalIgnoreCase))
                .OrderByDescending(p => p.Sequence).FirstOrDefault();
        }
        catch (Exception e) when (e is ManagementException or UnauthorizedAccessException or System.Runtime.InteropServices.COMException) { return null; }
    }

    public RestoreResult Create(string description = "AkariOS")
    {
        try
        {
            Checkpoint(description);
            log.Write("Restore point created");
            return new(true, "");
        }
        catch (Exception e) { log.Write($"Restore point: {e.Message} Trying again with System Protection on."); }

        var old = Safe(() => registry.GetValue(Key, Throttle));
        try
        {
            restore.EnableProtection();
            registry.SetValue(Key, Throttle, 0, "DWord");
            Checkpoint(description);
            log.Write("Restore point created");
            return new(true, "");
        }
        catch (Exception e)
        {
            log.Write($"Restore point failed: {e.Message}");
            return new(false, e.Message);
        }
        finally
        {
            try
            {
                if (old is null) registry.RemoveValue(Key, Throttle);
                else registry.SetValue(Key, Throttle, old, "DWord");
            }
            catch (Exception e) { log.WriteFile($"Restore point: the throttle could not be put back: {e.Message}"); }
        }
    }

    // a point Windows skips (made in the last 24 hours) is no error there: the list must have a new one
    private void Checkpoint(string description)
    {
        var before = Safe(() => restore.List().Max(p => (uint?)p.Sequence));
        restore.Create(description);
        var after = Safe(() => restore.List().Max(p => (uint?)p.Sequence));
        if (after is null || before is not null && after <= before)
            throw new InvalidOperationException("Windows skipped it: one was made in the last 24 hours.");
    }

    private static T? Safe<T>(Func<T> f)
    {
        try { return f(); } catch (Exception) { return default; }
    }
}

/// <summary>The real System Restore, through WMI (root\default: SystemRestore).</summary>
public sealed class WmiSystemRestore : ISystemRestore
{
    public WmiSystemRestore() => SystemGuard.Check("System Restore");

    public IReadOnlyList<RestorePoint> List()
    {
        using var s = new ManagementObjectSearcher(new ManagementScope(@"\\.\root\default"), new ObjectQuery("SELECT * FROM SystemRestore"));
        var points = new List<RestorePoint>();
        foreach (var o in s.Get())
            using (o)
            {
                DateTime? date = null;
                try { date = ManagementDateTimeConverter.ToDateTime((string)o["CreationTime"]); } catch (Exception) { }
                points.Add(new RestorePoint((string)o["Description"] ?? "", date, (uint)o["SequenceNumber"]));
            }
        return points;
    }

    public void Create(string description)
    {
        using var c = new ManagementClass(new ManagementScope(@"\\.\root\default"), new ManagementPath("SystemRestore"), null);
        using var p = c.GetMethodParameters("CreateRestorePoint");
        p["Description"] = description;
        p["RestorePointType"] = 12; // MODIFY_SETTINGS
        p["EventType"] = 100; // BEGIN_SYSTEM_CHANGE
        using var r = c.InvokeMethod("CreateRestorePoint", p, null);
        var code = Convert.ToUInt32(r["ReturnValue"]);
        if (code != 0) throw new InvalidOperationException($"System Restore refused (0x{code:x8}): is System Protection on?");
    }

    public void EnableProtection()
    {
        using var c = new ManagementClass(new ManagementScope(@"\\.\root\default"), new ManagementPath("SystemRestore"), null);
        using var p = c.GetMethodParameters("Enable");
        p["Drive"] = Path.GetPathRoot(Environment.SystemDirectory);
        using var r = c.InvokeMethod("Enable", p, null);
        var code = Convert.ToUInt32(r["ReturnValue"]);
        if (code != 0) throw new InvalidOperationException($"System Protection could not be turned on (0x{code:x8})");
    }
}
