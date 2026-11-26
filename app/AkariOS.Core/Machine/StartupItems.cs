using System.Diagnostics;
using AkariOS.Core.Data;
using AkariOS.Core.Registry;

namespace AkariOS.Core.Machine;

/// <summary>Where startup entries live (Get-AkariStartupLocations): Scope User | Machine, Kind Registry | Folder, Path = a
/// key or a folder, Approved = its StartupApproved key.</summary>
public sealed record StartupLocation(string Location, string Scope, string Kind, string Path, string Approved);

/// <summary>A startup entry (Get-AkariStartupItems): File = the Startup folder's file ('' for a Run value).</summary>
public sealed record StartupItem(string Key, string Name, string Command, string Location, string Scope, string Kind, string Path,
    string File, string Approved, bool Enabled, string Publisher);

/// <summary>
/// Startup apps (src/Core/Startup.ps1, plan 2026-11-26-new-features.md X2): the Run keys and the Startup folders, as Task
/// Manager's Startup apps lists them, each on or off through Explorer's StartupApproved value (Task Manager's own
/// switch: turned back on, it runs as it did); Remove deletes the value or file. The pure parts are compared with the
/// PowerShell app's by StartupOracleTests.
/// </summary>
public sealed class StartupItems(RegistryEngine registry, IReadOnlyList<StartupLocation> locations, Func<string, string>? publisher = null)
{
    public const string ApprovedRoot = @"Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved";
    private const string Run = @"Software\Microsoft\Windows\CurrentVersion\Run";

    /// <summary>The real places: the real user's Run key and Startup folder, the machine's Run keys (64- and 32-bit) and
    /// its Startup folder (Shell Folders' Common Startup, else under ProgramData; none without either).</summary>
    public static IReadOnlyList<StartupLocation> Locations(RegistryEngine registry, TweakServices services)
    {
        var common = PsSemantics.Text(registry.GetValue(@"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders", "Common Startup"));
        if (string.IsNullOrEmpty(common) && services.ProgramData.Length > 0)
            common = Path.Combine(services.ProgramData, @"Microsoft\Windows\Start Menu\Programs\StartUp");
        var user = UserFolders.Get(registry, "Startup", services.UserSid);
        var list = new List<StartupLocation>
        {
            new("Registry, this user", "User", "Registry", $@"HKCU:\{Run}", $@"HKCU:\{ApprovedRoot}\Run"),
            new("Registry, all users", "Machine", "Registry", $@"HKLM:\{Run}", $@"HKLM:\{ApprovedRoot}\Run"),
            new("Registry, all users (32-bit)", "Machine", "Registry", @"HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run", $@"HKLM:\{ApprovedRoot}\Run32"),
        };
        if (!string.IsNullOrEmpty(user)) list.Add(new("Startup folder, this user", "User", "Folder", user, $@"HKCU:\{ApprovedRoot}\StartupFolder"));
        if (!string.IsNullOrEmpty(common)) list.Add(new("Startup folder, all users", "Machine", "Folder", common, $@"HKLM:\{ApprovedRoot}\StartupFolder"));
        return list;
    }

    /// <summary>Test-AkariStartupApproved (pure): missing = on; else bit 0 of the first byte set = off.</summary>
    public static bool IsEnabled(object? value) => value is not byte[] { Length: > 0 } b || (b[0] & 1) == 0;

    /// <summary>ConvertTo-AkariStartupApproved (pure): on = 02 and eleven zero bytes; off = 03 00 00 00 and the time
    /// as a FILETIME.</summary>
    public static byte[] Approved(bool enabled, DateTime whenUtc)
    {
        var b = new byte[12];
        b[0] = enabled ? (byte)2 : (byte)3;
        if (!enabled) BitConverter.GetBytes(whenUtc.ToFileTimeUtc()).CopyTo(b, 4);
        return b;
    }

    /// <summary>Get-AkariStartupProgram (pure): the quoted part, else up to the first .exe, else the first word.</summary>
    public static string Program(string? command)
    {
        var c = (command ?? "").Trim();
        if (c.Length == 0) return "";
        if (c.StartsWith('"'))
        {
            var end = c.IndexOf('"', 1);
            return end > 0 ? c[1..end] : c[1..];
        }
        var exe = c.IndexOf(".exe", StringComparison.OrdinalIgnoreCase);
        if (exe > 0) return c[..(exe + 4)];
        var sp = c.IndexOf(' ');
        return sp > 0 ? c[..sp] : c;
    }

    /// <summary>Get-AkariFilePublisher: the company in a program's version information ('' when unknown).</summary>
    public static string Publisher(string path)
    {
        try
        {
            var p = Environment.ExpandEnvironmentVariables(path);
            return p.Length > 0 && System.IO.File.Exists(p) ? (FileVersionInfo.GetVersionInfo(p).CompanyName ?? "").Trim() : "";
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or ArgumentException) { return ""; }
    }

    /// <summary>Get-AkariStartupKey.</summary>
    public static string KeyOf(string location, string name) => $"{location}|{name}";

    /// <summary>Get-AkariStartupItems: every entry, in the locations' order.</summary>
    public IReadOnlyList<StartupItem> All()
    {
        var pub = publisher ?? Publisher;
        var list = new List<StartupItem>();
        foreach (var l in locations)
        {
            var entries = new List<(string Name, string Command, string File)>();
            if (l.Kind == "Registry")
            {
                if (!registry.KeyExists(l.Path)) continue;
                foreach (var n in registry.ValueNames(l.Path))
                    if (n != "(default)") entries.Add((n, PsSemantics.Text(registry.GetValue(l.Path, n)) ?? "", ""));
            }
            else
            {
                if (!Directory.Exists(l.Path)) continue;
                foreach (var f in Directory.GetFiles(l.Path))
                {
                    var n = System.IO.Path.GetFileName(f);
                    if (!n.Equals("desktop.ini", StringComparison.OrdinalIgnoreCase)) entries.Add((n, f, f));
                }
            }
            foreach (var (name, command, file) in entries)
                list.Add(new StartupItem(KeyOf(l.Location, name), name, command, l.Location, l.Scope, l.Kind, l.Path, file, l.Approved,
                    IsEnabled(registry.GetValue(l.Approved, name)), pub(Program(command))));
        }
        return list;
    }

    /// <summary>Set-AkariStartupEnabled: its StartupApproved value; throws when Windows keeps it as it was.</summary>
    public void SetEnabled(StartupItem item, bool enabled, DateTime nowUtc)
    {
        registry.SetValue(item.Approved, item.Name, Approved(enabled, nowUtc), "Binary");
        if (IsEnabled(registry.GetValue(item.Approved, item.Name)) != enabled)
            throw new InvalidOperationException($"Windows keeps it {(enabled ? "off" : "on")}");
    }

    /// <summary>Remove-AkariStartupItem: its Run value or Startup folder file, then its StartupApproved value.</summary>
    public void Remove(StartupItem item)
    {
        if (item.Kind == "Registry")
        {
            if (registry.GetValue(item.Path, item.Name) is not null) registry.RemoveValue(item.Path, item.Name);
            if (registry.GetValue(item.Path, item.Name) is not null) throw new InvalidOperationException("Windows keeps it: the value could not be deleted");
        }
        else if (item.File.Length > 0 && System.IO.File.Exists(item.File)) System.IO.File.Delete(item.File);
        if (registry.GetValue(item.Approved, item.Name) is not null) registry.RemoveValue(item.Approved, item.Name);
    }
}
