using System.Runtime.InteropServices;
using AkariOS.Core.Registry;

namespace AkariOS.Core.Iso;

/// <summary>
/// The real <see cref="IOfflineHives"/> (guarded): a mounted image's hive file loaded at HKLM\AkariIso_&lt;name&gt; with
/// RegLoadKey, unloaded with RegUnLoadKey (SeBackup and SeRestore turned on first). Before an unload the garbage
/// collector runs: a registry handle .NET still holds keeps the hive loaded (the build retries a few times).
/// </summary>
public sealed partial class OfflineHives : IOfflineHives
{
    private static readonly nint LocalMachine = unchecked((int)0x80000002);

    public OfflineHives()
    {
        SystemGuard.Check("offline hives");
        TrustedInstaller.EnablePrivilege("SeBackupPrivilege");
        TrustedInstaller.EnablePrivilege("SeRestorePrivilege");
    }

    /// <summary>The key under HKLM a hive loads at.</summary>
    public static string KeyName(string name) => $"AkariIso_{name}";

    public bool Load(string name, string file) => RegLoadKeyW(LocalMachine, KeyName(name), file) == 0;

    public bool Unload(string name)
    {
        GC.Collect();
        GC.WaitForPendingFinalizers();
        return RegUnLoadKeyW(LocalMachine, KeyName(name)) == 0;
    }

    [LibraryImport("advapi32.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int RegLoadKeyW(nint key, string subKey, string file);

    [LibraryImport("advapi32.dll", StringMarshalling = StringMarshalling.Utf16)]
    private static partial int RegUnLoadKeyW(nint key, string subKey);
}
