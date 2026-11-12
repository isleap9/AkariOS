using System.Security.AccessControl;
using System.Security.Principal;
using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using Microsoft.Win32;

namespace AkariOS.Core.Tests;

/// <summary>ServiceStart against Set-AkariServiceStart (Oracle/Invoke-ServiceStart.ps1): each on its own test key with
/// the same services, the same values written (a per-user instance's template too), the same failures; a refused admin
/// write goes through TrustedInstaller.</summary>
public sealed class ServiceStartTests : IDisposable
{
    private readonly TestKey _cs = new();
    private readonly TestKey _ps = new();

    public void Dispose() { _cs.Dispose(); _ps.Dispose(); }

    private sealed class Trusted(Action? before = null) : ITrustedInstaller
    {
        public int Runs { get; private set; }
        public bool Write { get; init; }
        public void Run(Action work) { Runs++; before?.Invoke(); if (Write) work(); }
    }

    private const string Services = @"SYSTEM\CurrentControlSet\Services";

    private void Service(string name, uint start, uint delayed = 0)
    {
        foreach (var k in new[] { _cs, _ps })
        {
            var reg = new RegistryEngine(k.Paths);
            reg.SetValue($@"{ServiceStart.Root}\{name}", "Start", start, "DWord");
            reg.SetValue($@"{ServiceStart.Root}\{name}", "DelayedAutostart", delayed, "DWord");
        }
    }

    private (string Error, List<string> Trusted) Ps(string name, string startType, string refuse = ";")
    {
        var r = Oracle.Run("Invoke-ServiceStart.ps1", ["-Src", Repo.Src, "-Root", _ps.Real("HKLM", Services), "-Name", name, "-StartType", startType, "-Refuse", refuse]);
        return (r.GetProperty("Error").GetString()!, r.GetProperty("Trusted").EnumerateArray().Select(e => e.GetString()!).ToList());
    }

    private string Cs(string name, string startType, ITrustedInstaller? trusted = null)
    {
        try { ServiceStart.Set(new RegistryEngine(_cs.Paths, trusted), name, startType); return ""; }
        catch (InvalidOperationException e) { return e.Message; }
    }

    private static List<string> Values(TestKey k, params string[] names)
    {
        var reg = new RegistryEngine(k.Paths);
        return names.SelectMany(n => new[] { "Start", "DelayedAutostart" }.Select(v => $"{n}.{v}={reg.GetValue($@"{ServiceStart.Root}\{n}", v)}")).ToList();
    }

    [Theory]
    [InlineData("Automatic")]
    [InlineData("AutomaticDelayed")]
    [InlineData("Manual")]
    [InlineData("Disabled")]
    public void Writes_start_and_delayed_as_powershell(string type)
    {
        Service("BITS", 3, 1);
        Assert.Equal(Ps("BITS", type).Error, Cs("BITS", type));
        Assert.Equal(Values(_ps, "BITS"), Values(_cs, "BITS"));
    }

    [Fact]
    public void A_per_user_instance_changes_its_template_too()
    {
        Service("cbdhsvc", 2);
        Service("cbdhsvc_4f2a1", 2);
        Assert.Equal(Ps("cbdhsvc_4f2a1", "Disabled").Error, Cs("cbdhsvc_4f2a1", "Disabled"));
        Assert.Equal(Values(_ps, "cbdhsvc", "cbdhsvc_4f2a1"), Values(_cs, "cbdhsvc", "cbdhsvc_4f2a1"));
        Assert.Equal("cbdhsvc.Start=4", Values(_cs, "cbdhsvc")[0]);
    }

    [Fact]
    public void A_missing_service_fails_the_same()
    {
        var ps = Ps("Nope", "Manual").Error;
        Assert.Equal("no service named Nope", ps);
        Assert.Equal(ps, Cs("Nope", "Manual"));
    }

    // the admin write refused (a deny rule on the C# key, -Refuse on the PowerShell side)
    private void Refuse(string name, bool on)
    {
        using var k = Microsoft.Win32.Registry.CurrentUser.OpenSubKey($@"{_cs.Root}\HKLM\{Services}\{name}", RegistryKeyPermissionCheck.ReadWriteSubTree, RegistryRights.ChangePermissions | RegistryRights.ReadKey)!;
        var acl = k.GetAccessControl();
        var rule = new RegistryAccessRule(WindowsIdentity.GetCurrent().User!, RegistryRights.SetValue, AccessControlType.Deny);
        if (on) acl.AddAccessRule(rule); else acl.RemoveAccessRule(rule);
        k.SetAccessControl(acl);
    }

    [Fact]
    public void A_refused_write_goes_through_trustedinstaller_and_fails_when_windows_keeps_it()
    {
        Service("WinDefend", 2);
        Refuse("WinDefend", true);
        try
        {
            var (error, rows) = Ps("WinDefend", "Disabled", "WinDefend");
            Assert.Equal(["WinDefend|Start|4", "WinDefend|DelayedAutostart|0"], rows);
            var trusted = new Trusted();
            Assert.Equal(error, Cs("WinDefend", "Disabled", trusted));
            Assert.Equal("Windows keeps the startup type of WinDefend (a protected service: some change only in Safe Mode)", error);
            Assert.Equal(1, trusted.Runs);

            // TrustedInstaller may: the value changes
            var allowed = new Trusted(() => Refuse("WinDefend", false)) { Write = true };
            Assert.Equal("", Cs("WinDefend", "Disabled", allowed));
            Assert.Equal("WinDefend.Start=4", Values(_cs, "WinDefend")[0]);
        }
        finally { try { Refuse("WinDefend", false); } catch (Exception) { } }
    }
}
