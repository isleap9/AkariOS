using System.Diagnostics;
using System.Diagnostics.Eventing.Reader;
using System.Globalization;
using System.Management;
using System.ServiceProcess;
using System.Xml.Linq;
using AkariOS.Core.Runs;

namespace AkariOS.Core.Machine;

/// <summary>The readers behind the numbers (Get-AkariMemoryInUse, Get-AkariRunningCounts, Get-AkariBootSeconds,
/// Get-AkariLastBoot); tests fake them.</summary>
public interface IMetricsReader
{
    int? RamMB();
    (int Processes, int Services)? Counts();
    double? BootSeconds();
    DateTime LastBoot();
}

/// <summary>The real readers: WMI's Win32_OperatingSystem, the process and service lists, the Diagnostics-Performance
/// log's event 100. Guarded.</summary>
public sealed class LiveMetricsReader : IMetricsReader
{
    public LiveMetricsReader() => SystemGuard.Check("System metrics");

    private static ManagementObject? Os()
    {
        using var s = new ManagementObjectSearcher("SELECT TotalVisibleMemorySize, FreePhysicalMemory, LastBootUpTime FROM Win32_OperatingSystem");
        return s.Get().OfType<ManagementObject>().FirstOrDefault();
    }

    public int? RamMB()
    {
        try
        {
            using var o = Os();
            return o is null ? null : (int)Math.Round((System.Convert.ToDouble(o["TotalVisibleMemorySize"]) - System.Convert.ToDouble(o["FreePhysicalMemory"])) / 1024);
        }
        catch (ManagementException) { return null; }
    }

    public (int Processes, int Services)? Counts()
    {
        try { return (Process.GetProcesses().Length, ServiceController.GetServices().Count(s => s.Status == ServiceControllerStatus.Running)); }
        catch (Exception e) when (e is InvalidOperationException or System.ComponentModel.Win32Exception) { return null; }
    }

    public double? BootSeconds()
    {
        try
        {
            var q = new EventLogQuery("Microsoft-Windows-Diagnostics-Performance/Operational", PathType.LogName, "*[System[EventID=100]]") { ReverseDirection = true };
            using var r = new EventLogReader(q);
            using var e = r.ReadEvent();
            if (e is null) return null;
            var x = XElement.Parse(e.ToXml());
            var ms = x.Descendants().FirstOrDefault(d => d.Name.LocalName == "Data" && (string?)d.Attribute("Name") == "BootTime")?.Value;
            return double.TryParse(ms, NumberStyles.Float, CultureInfo.InvariantCulture, out var v) ? Math.Round(v / 1000, 1) : null;
        }
        catch (Exception e) when (e is EventLogException or UnauthorizedAccessException or System.Xml.XmlException) { return null; }
    }

    public DateTime LastBoot() => DateTime.Now - TimeSpan.FromMilliseconds(Environment.TickCount64);
}

/// <summary>
/// Before and after numbers (src/Core/Metrics.ps1, plan 2026-11-26-new-features.md X6): read when a Guided or One-click
/// Run starts (its history record's 'Before') and at the first launch after its restart, once Windows has been up
/// <see cref="Settle"/> ('After'); Home shows them side by side. The pure parts are compared with the PowerShell
/// app's by MetricsTests.
/// </summary>
public static class Metrics
{
    /// <summary>$AkariMetricNames, in Home's order.</summary>
    public static readonly (string Key, string Name)[] Names =
        [("RamMB", "RAM in use"), ("Processes", "Processes"), ("Services", "Running services"), ("Startup", "Startup apps on"), ("BootSeconds", "Boot time")];

    public static readonly TimeSpan Settle = TimeSpan.FromSeconds(180);

    /// <summary>Get-AkariMetrics: every number that can be read.</summary>
    public static Dictionary<string, double> Read(IMetricsReader reader, Func<int?>? startup = null)
    {
        var m = new Dictionary<string, double>(StringComparer.OrdinalIgnoreCase);
        if (reader.RamMB() is { } ram) m["RamMB"] = ram;
        if (reader.Counts() is { } c) { m["Processes"] = c.Processes; m["Services"] = c.Services; }
        try { if (startup?.Invoke() is { } s) m["Startup"] = s; } catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
        if (reader.BootSeconds() is { } b) m["BootSeconds"] = b;
        return m;
    }

    /// <summary>Format-AkariMetric (pure).</summary>
    public static string Format(string key, double value) => key switch
    {
        "RamMB" => (value / 1024).ToString("0.0", CultureInfo.InvariantCulture) + " GB",
        "BootSeconds" => value.ToString("0.#", CultureInfo.InvariantCulture) + " s",
        _ => ((long)value).ToString(CultureInfo.InvariantCulture),
    };

    /// <summary>A row Home shows.</summary>
    public sealed record Row(string Key, string Name, string Before, string After)
    {
        public string Text => $"{Before} → {After}";
    }

    /// <summary>Get-AkariMetricsDiff (pure): each number both sides have, in <see cref="Names"/>' order.</summary>
    public static IReadOnlyList<Row> Diff(IReadOnlyDictionary<string, double>? before, IReadOnlyDictionary<string, double>? after) =>
        before is null || after is null ? []
            : Names.Where(n => before.ContainsKey(n.Key) && after.ContainsKey(n.Key))
                .Select(n => new Row(n.Key, n.Name, Format(n.Key, before[n.Key]), Format(n.Key, after[n.Key]))).ToList();

    /// <summary>Test-AkariMetricsDue (pure): "Due", "Wait" or "No".</summary>
    public static string Due(HistoryRecord r, DateTime lastBoot, DateTime now)
    {
        if (!r.Metrics.ContainsKey("Before") || r.Metrics.ContainsKey("After")) return "No";
        if (!DateTime.TryParse(r.When, CultureInfo.InvariantCulture, DateTimeStyles.RoundtripKind, out var when)) return "No";
        if (lastBoot <= when) return "No";
        return now - lastBoot < Settle ? "Wait" : "Due";
    }

    /// <summary>Find-AkariMetricsPending (pure): the newest record whose 'After' is due or waiting.</summary>
    public static (HistoryRecord Record, string State)? Pending(IEnumerable<HistoryRecord> newestFirst, DateTime lastBoot, DateTime now)
    {
        foreach (var r in newestFirst)
            if (Due(r, lastBoot, now) is var s and not "No") return (r, s);
        return null;
    }

    /// <summary>Get-AkariMetricsShown (pure): the newest record with both sides.</summary>
    public static HistoryRecord? Shown(IEnumerable<HistoryRecord> newestFirst) =>
        newestFirst.FirstOrDefault(r => r.Metrics.ContainsKey("Before") && r.Metrics.ContainsKey("After"));
}
