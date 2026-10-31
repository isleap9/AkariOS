using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Security.Principal;
using Microsoft.Win32;

namespace AkariOS.Core.Registry;

/// <summary>A registry key: its hive and the path under it ('' = the hive itself).</summary>
public readonly record struct RegKeyPath(RegistryHive Hive, string Sub);

/// <summary>Where a Tweak row's path is on this machine (rule 6: HKCU = the real logged-in user's hive).</summary>
public interface IRegistryPaths
{
    RegKeyPath Resolve(string path);
}

public static class RegPath
{
    /// <summary>
    /// A path as Tweak rows write it (HKLM:\..., HKCU:\..., HKEY_LOCAL_MACHINE\..., Registry::HKEY_USERS\...) as its
    /// hive name ('HKLM', 'HKCU', 'HKU', 'HKCR', 'HKCC') and subkey; throws on any other form. Pure.
    /// </summary>
    public static (string Hive, string Sub) Split(string path)
    {
        var p = path.StartsWith("Registry::", StringComparison.OrdinalIgnoreCase) ? path[10..] : path;
        var cut = p.IndexOfAny([':', '\\']);
        var head = (cut < 0 ? p : p[..cut]).ToUpperInvariant();
        var rest = cut < 0 ? "" : p[cut..].TrimStart(':').Trim('\\');
        var hive = head switch
        {
            "HKLM" or "HKEY_LOCAL_MACHINE" => "HKLM",
            "HKCU" or "HKEY_CURRENT_USER" => "HKCU",
            "HKU" or "HKEY_USERS" => "HKU",
            "HKCR" or "HKEY_CLASSES_ROOT" => "HKCR",
            "HKCC" or "HKEY_CURRENT_CONFIG" => "HKCC",
            _ => throw new ArgumentException($"'{path}' is not a registry path Akari reads", nameof(path)),
        };
        // the provider form needs its colon (HKLM:\), the .NET form its backslash (HKEY_LOCAL_MACHINE\)
        if (cut >= 0 && p[cut] == ':' && head.StartsWith("HKEY_", StringComparison.Ordinal))
            throw new ArgumentException($"'{path}' is not a registry path Akari reads", nameof(path));
        return (hive, rest);
    }

    public static RegistryHive HiveOf(string name) => name switch
    {
        "HKLM" => RegistryHive.LocalMachine,
        "HKCU" => RegistryHive.CurrentUser,
        "HKU" => RegistryHive.Users,
        "HKCR" => RegistryHive.ClassesRoot,
        "HKCC" => RegistryHive.CurrentConfig,
        _ => throw new ArgumentException(name),
    };

    internal static string Join(string a, string b) => a.Length == 0 ? b : b.Length == 0 ? a : $@"{a}\{b}";
}

/// <summary>The machine's registry: HKCU rows go to HKEY_USERS\&lt;the real user's SID&gt;.</summary>
public sealed class LiveRegistryPaths : IRegistryPaths
{
    private readonly IUserSid _user;

    public LiveRegistryPaths(IUserSid user)
    {
        SystemGuard.Check("The live registry");
        _user = user;
    }

    public RegKeyPath Resolve(string path)
    {
        var (hive, sub) = RegPath.Split(path);
        return hive == "HKCU" ? new RegKeyPath(RegistryHive.Users, RegPath.Join(_user.Sid, sub)) : new RegKeyPath(RegPath.HiveOf(hive), sub);
    }
}

/// <summary>Tests: every hive under HKEY_CURRENT_USER\&lt;root&gt;\&lt;HKLM|HKCU|...&gt; (root = Software\AkariTest\&lt;guid&gt;).</summary>
public sealed class RedirectedRegistryPaths(string root) : IRegistryPaths
{
    public string Root { get; } = root;

    public RegKeyPath Resolve(string path)
    {
        var (hive, sub) = RegPath.Split(path);
        return new RegKeyPath(RegistryHive.CurrentUser, RegPath.Join($@"{Root}\{hive}", sub));
    }
}

/// <summary>The SID of the user whose HKCU Akari changes.</summary>
public interface IUserSid
{
    string Sid { get; }
}

/// <summary>
/// The real logged-in user (Get-AkariUserSid): the owner of explorer.exe in this session, so an Akari elevated with
/// another admin account changes the user at the desk; else the account Akari runs as. Override = a Run's saved SID
/// (a later phase running as SYSTEM).
/// </summary>
public sealed partial class RealUserSid(string? overrideSid = null) : IUserSid
{
    private readonly Lazy<string> _sid = new(() => overrideSid ?? Detect());

    public string Sid => _sid.Value;

    private static string Detect()
    {
        try
        {
            var session = Process.GetCurrentProcess().SessionId;
            foreach (var p in Process.GetProcessesByName("explorer"))
            {
                using (p)
                {
                    if (p.SessionId != session) continue;
                    var sid = OwnerOf(p);
                    if (sid != null) return sid;
                }
            }
        }
        catch (Exception e) when (e is Win32Exception or InvalidOperationException) { }
        return WindowsIdentity.GetCurrent().User!.Value;
    }

    private static string? OwnerOf(Process p)
    {
        if (!OpenProcessToken(p.Handle, TokenQuery, out var token)) return null;
        try
        {
            using var id = new WindowsIdentity(token);
            return id.User?.Value;
        }
        finally { CloseHandle(token); }
    }

    private const uint TokenQuery = 0x0008;

    [LibraryImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool CloseHandle(IntPtr handle);
}
