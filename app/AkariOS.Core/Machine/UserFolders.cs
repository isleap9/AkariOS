using AkariOS.Core.Data;
using AkariOS.Core.Registry;

namespace AkariOS.Core.Machine;

/// <summary>
/// The real user's folders (Get-AkariUserFolder): Explorer's Shell Folders in their hive (HKCU goes to the logged-in
/// user, not the elevated account), else their profile folder from ProfileList. Names as Shell Folders has them:
/// AppData, Local AppData, Desktop, Programs, Downloads…
/// </summary>
public static class UserFolders
{
    private const string ShellFolders = @"HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders";

    /// <summary>The folder, or null when neither the user's Shell Folders nor their profile say.</summary>
    public static string? Get(RegistryEngine registry, string name, string? userSid = null)
    {
        // Shell Folders names Downloads by its known-folder GUID
        var value = name == "Downloads" ? "{374DE290-123F-4565-9164-39C4925E467B}" : name;
        if (PsSemantics.Text(registry.GetValue(ShellFolders, value)) is { Length: > 0 } p) return p;
        var profile = userSid is null ? null
            : PsSemantics.Text(registry.GetValue($@"HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\{userSid}", "ProfileImagePath"));
        if (string.IsNullOrEmpty(profile)) return null;
        return name switch
        {
            "AppData" => Path.Combine(profile, "AppData", "Roaming"),
            "Local AppData" => Path.Combine(profile, "AppData", "Local"),
            "Programs" => Path.Combine(profile, @"AppData\Roaming\Microsoft\Windows\Start Menu\Programs"),
            _ => Path.Combine(profile, name),
        };
    }
}
