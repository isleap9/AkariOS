using System.Management;
using System.Runtime.InteropServices;

namespace AkariOS.Core.Machine;

/// <summary>A physical network adapter: its interface index (netsh's name=), name and interface GUID ({…}, its keys under
/// Tcpip\Parameters\Interfaces and Dnscache\InterfaceSpecificParameters).</summary>
public sealed record DnsAdapter(int Index, string Name, string Guid);

/// <summary>Get-AkariDnsAdapters and Clear-AkariDnsCache: the adapters DNS servers are set on (the servers themselves
/// change through INetsh), and the DNS client's cache.</summary>
public interface IDnsClient
{
    /// <summary>The physical adapters, up or not, by interface index.</summary>
    IReadOnlyList<DnsAdapter> Adapters();

    void FlushCache();
}

/// <summary>The real one (guarded): MSFT_NetAdapter with HardwareInterface (Get-NetAdapter -Physical's adapters), and
/// dnsapi's DnsFlushResolverCache (Clear-DnsClientCache).</summary>
public sealed partial class WmiDnsClient : IDnsClient
{
    public WmiDnsClient() => SystemGuard.Check("DNS client");

    public IReadOnlyList<DnsAdapter> Adapters()
    {
        using var s = new ManagementObjectSearcher(@"root\StandardCimv2",
            "SELECT InterfaceIndex, Name, InterfaceGuid FROM MSFT_NetAdapter WHERE HardwareInterface = TRUE");
        var list = new List<DnsAdapter>();
        foreach (ManagementObject o in s.Get())
            using (o)
                list.Add(new DnsAdapter(Convert.ToInt32(o["InterfaceIndex"]), $"{o["Name"]}", $"{o["InterfaceGuid"]}"));
        return list.OrderBy(a => a.Index).ToList();
    }

    public void FlushCache() => DnsFlushResolverCache();

    [LibraryImport("dnsapi.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool DnsFlushResolverCache();
}
