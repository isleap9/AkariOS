using AkariOS.Core.Registry;
using AkariOS.Core.Runs;

namespace AkariOS.Core.Tests;

public sealed class RestorePointsTests : IDisposable
{
    private readonly TestKey _key = new();
    private readonly RegistryEngine _reg;
    private readonly MemoryLog _log = new();

    public RestorePointsTests() => _reg = new RegistryEngine(_key.Paths);

    public void Dispose() => _key.Dispose();

    /// <summary>System Restore that refuses the first N tries, or skips them silently (the 24 hour throttle).</summary>
    private sealed class FakeRestore : ISystemRestore
    {
        public List<RestorePoint> Points { get; } = [new("Windows Update", null, 3)];
        public int Refuse { get; set; }
        public int Skip { get; set; }
        public bool Enabled { get; private set; }
        public Action? OnCreate { get; set; }

        public IReadOnlyList<RestorePoint> List() => Points;

        public void Create(string description)
        {
            OnCreate?.Invoke();
            if (Refuse-- > 0) throw new InvalidOperationException("System Protection is off.");
            if (Skip-- > 0) return;
            Points.Add(new(description, DateTime.Now, Points.Max(p => p.Sequence) + 1));
        }

        public void EnableProtection() => Enabled = true;
    }

    [Fact]
    public void Made_the_first_time()
    {
        var sr = new FakeRestore();
        var r = new RestorePoints(sr, _reg, _log).Create();
        Assert.Equal(new RestoreResult(true, ""), r);
        Assert.False(sr.Enabled);
        Assert.Equal("AkariOS", new RestorePoints(sr, _reg, _log).Latest()!.Description);
    }

    [Theory]
    [InlineData(1, 0)]
    [InlineData(0, 1)]
    public void Refused_or_skipped_turns_protection_on_and_lifts_the_throttle_once(int refuse, int skip)
    {
        var sr = new FakeRestore { Refuse = refuse, Skip = skip };
        var throttles = new List<object?>();
        sr.OnCreate = () => throttles.Add(_reg.GetValue(RestorePoints.Key, RestorePoints.Throttle));
        _reg.SetValue(RestorePoints.Key, RestorePoints.Throttle, 1440, "DWord");

        Assert.True(new RestorePoints(sr, _reg, _log).Create().Ok);
        Assert.True(sr.Enabled);
        Assert.Equal([1440u, 0u], throttles);
        Assert.Equal(1440u, _reg.GetValue(RestorePoints.Key, RestorePoints.Throttle));
    }

    [Fact]
    public void A_throttle_that_was_not_set_is_removed_again()
    {
        var sr = new FakeRestore { Skip = 1 };
        Assert.True(new RestorePoints(sr, _reg, _log).Create().Ok);
        Assert.Null(_reg.GetValue(RestorePoints.Key, RestorePoints.Throttle));
    }

    [Fact]
    public void Never_throws()
    {
        var r = new RestorePoints(new FakeRestore { Refuse = 2 }, _reg, _log).Create();
        Assert.Equal(new RestoreResult(false, "System Protection is off."), r);
        Assert.Contains("Restore point failed: System Protection is off.", _log.Lines);
    }

    [Fact]
    public void The_latest_is_akaris_newest()
    {
        var sr = new FakeRestore();
        sr.Points.Add(new("Akari", null, 7));
        sr.Points.Add(new("AkariOS", null, 9));
        sr.Points.Add(new("Installed Office", null, 12));
        Assert.Equal(9u, new RestorePoints(sr, _reg, _log).Latest()!.Sequence);
        Assert.Null(new RestorePoints(new FakeRestore(), _reg, _log).Latest());
    }

    [Fact]
    public void The_real_one_cant_be_made_in_a_test() => Assert.Throws<InvalidOperationException>(() => new WmiSystemRestore());

    [Fact]
    public void The_log_file_has_powershells_format()
    {
        var file = Path.Combine(Path.GetTempPath(), $"akari-log-{Guid.NewGuid():N}", "akari.log");
        var log = new AkariLog(file);
        var lines = new List<string>();
        log.Line += lines.Add;
        log.Write("Applied: x   ");
        log.Write("   ");
        log.WriteFile("Run started");
        Assert.Equal(["Applied: x"], lines);
        Assert.Matches(@"^\[\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\] Run started\r?\n$", File.ReadAllText(file));
        Directory.Delete(Path.GetDirectoryName(file)!, recursive: true);
    }
}
