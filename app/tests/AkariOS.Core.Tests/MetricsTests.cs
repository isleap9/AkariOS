using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Runs;

namespace AkariOS.Core.Tests;

/// <summary>Before and after numbers (X6, src/Core/Metrics.ps1's rules, the same cases as tests/Metrics.Tests.ps1): the
/// rows Home shows, when 'After' is due, a record's numbers kept through later writes. Files in a temp folder.</summary>
public sealed class MetricsTests : IDisposable
{
    private readonly TestKey _key = new();
    private readonly string _dir = Path.Combine(Path.GetTempPath(), $"akari-metrics-{Guid.NewGuid():N}");

    public void Dispose()
    {
        _key.Dispose();
        if (Directory.Exists(_dir)) Directory.Delete(_dir, true);
    }

    private sealed class Reader : IMetricsReader
    {
        public int? RamMB() => 2048;
        public (int Processes, int Services)? Counts() => (150, 80);
        public double? BootSeconds() => 20.5;
        public DateTime LastBoot() => new(2026, 11, 26, 11, 0, 0);
    }

    [Fact]
    public void Formats_and_compares_the_numbers_both_sides_have()
    {
        var rows = Metrics.Diff(new Dictionary<string, double> { ["RamMB"] = 2458, ["Processes"] = 180, ["BootSeconds"] = 35.25 },
            new Dictionary<string, double> { ["RamMB"] = 1536, ["Processes"] = 120, ["Services"] = 90, ["BootSeconds"] = 22 });
        Assert.Equal(["RAM in use: 2.4 GB > 1.5 GB", "Processes: 180 > 120", "Boot time: 35.3 s > 22 s"], rows.Select(r => $"{r.Name}: {r.Before} > {r.After}"));
        Assert.Equal("2.4 GB → 1.5 GB", rows[0].Text);
        Assert.Empty(Metrics.Diff(null, new Dictionary<string, double> { ["RamMB"] = 1 }));
        Assert.Equal(["RamMB=2048", "Processes=150", "Services=80", "Startup=3", "BootSeconds=20.5"],
            Metrics.Read(new Reader(), () => 3).Select(p => $"{p.Key}={p.Value.ToString(System.Globalization.CultureInfo.InvariantCulture)}"));
    }

    [Fact]
    public void After_is_read_once_windows_settled_after_a_restart_since_the_run()
    {
        var history = new RunHistory(_dir, new RegistryEngine(_key.Paths), new MemoryLog(), () => Metrics.Read(new Reader()));
        var h = history.New("Guided run", new DateTime(2026, 11, 26, 10, 0, 0));
        history.TakeBefore(h);
        history.AddOutcomes(h, [new Outcome("x", Tweaks.TweakMode.Apply, OutcomeKind.Applied, false, "")]);
        var r = history.Last()!;
        Assert.Equal("No", Metrics.Due(r, new DateTime(2026, 11, 26, 9, 0, 0), new DateTime(2026, 11, 26, 11, 0, 0)));
        Assert.Equal("Wait", Metrics.Due(r, new DateTime(2026, 11, 26, 10, 30, 0), new DateTime(2026, 11, 26, 10, 31, 0)));
        Assert.Equal("Due", Metrics.Due(r, new DateTime(2026, 11, 26, 10, 30, 0), new DateTime(2026, 11, 26, 10, 34, 0)));
        Assert.Null(Metrics.Shown(history.All()));
        history.SetMetrics(h, "After", new Dictionary<string, double> { ["RamMB"] = 1024 });
        var shown = Metrics.Shown(history.All())!;
        Assert.Equal(2048, shown.Metrics["Before"]["RamMB"]);
        Assert.Equal(1024, shown.Metrics["After"]["RamMB"]);
        Assert.Single(shown.Outcomes);
        Assert.Equal("No", Metrics.Due(shown, new DateTime(2026, 11, 26, 10, 30, 0), new DateTime(2026, 11, 26, 11, 0, 0)));
    }
}
