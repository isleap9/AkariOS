using AkariOS.Core.Apps;

namespace AkariOS.App.Tests;

/// <summary>The PC's Store packages for the App tests: removable ones by name, each with an optional logo folder.</summary>
internal sealed class FakePackages : IPackageManager
{
    public List<AppPackage> Packages { get; } = [];
    public List<string> Calls { get; } = [];
    public int Reads { get; private set; }

    public FakePackages Add(params string[] names)
    {
        foreach (var n in names) Packages.Add(new AppPackage(n, $"{n}_1.0.0.0_x64__8wekyb3d8bbwe", $"{n}_8wekyb3d8bbwe", null, false, false, false, false));
        return this;
    }

    public IReadOnlyList<AppPackage> AllUsers() { Reads++; return Packages.ToList(); }
    public void Remove(string fullName) { Calls.Add($"remove {fullName}"); Packages.RemoveAll(p => p.FullName == fullName); }
    public void RegisterByFamily(string family) => Calls.Add($"register-family {family}");
    public void Register(string manifest) => Calls.Add($"register {manifest}");
    public void Add(string file) => Calls.Add($"add {file}");
    public IReadOnlyList<ProvisionedApp> ProvisionedApps() => [];
    public void Deprovision(string family) => Calls.Add($"deprovision {family}");
}

/// <summary>The PC's Optional and Windows features; Reads counts the list reads (the Remove tab's background read).</summary>
internal sealed class FakeDism : IDism
{
    public List<DismItem> Capabilities { get; } = [];
    public List<DismItem> Features { get; } = [];
    public int Reads { get; private set; }

    IReadOnlyList<DismItem> IDism.Capabilities() { Reads++; return Capabilities.ToList(); }
    IReadOnlyList<DismItem> IDism.Features() { Reads++; return Features.ToList(); }
    public string? CapabilityState(string name) => Capabilities.FirstOrDefault(c => c.Name == name)?.State;
    public string? FeatureState(string name) => Features.FirstOrDefault(f => f.Name == name)?.State;
    public void RemoveCapability(string name) { }
    public void DisableFeature(string name) { }
}
