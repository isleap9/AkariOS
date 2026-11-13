using System.Security.AccessControl;
using System.Security.Principal;

namespace AkariOS.Core.Machine;

/// <summary>Set-AkariAdminOnlyAcl: a file only Administrators and SYSTEM may read or write (inheritance off), made empty
/// when it is missing (what sshd asks of administrators_authorized_keys). Get- / Set-AkariDenyRule: the rights Everyone
/// is denied on a file or folder by its own rules.</summary>
public interface IFileAcl
{
    void AdminsOnly(string path);

    /// <summary>The FileSystemRights mask Everyone (S-1-1-0) is denied by the item's explicit rules; 0 with none or no
    /// such item.</summary>
    int Denied(string path);

    /// <summary>Everyone denied <paramref name="rights"/> on the item alone, replacing Everyone's earlier deny rules; 0
    /// only removes them. Only the access rules are written, never the owner.</summary>
    void SetDeny(string path, int rights);
}

/// <summary>The real one (guarded): the file's ACL replaced, by SIDs (every language).</summary>
public sealed class FileAcl : IFileAcl
{
    public FileAcl() => SystemGuard.Check("File permissions");

    public void AdminsOnly(string path)
    {
        if (!File.Exists(path))
        {
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            File.WriteAllText(path, "");
        }
        var file = new FileInfo(path);
        var acl = file.GetAccessControl();
        acl.SetAccessRuleProtection(isProtected: true, preserveInheritance: false);
        foreach (FileSystemAccessRule r in acl.GetAccessRules(true, true, typeof(SecurityIdentifier))) acl.RemoveAccessRule(r);
        foreach (var sid in new[] { WellKnownSidType.BuiltinAdministratorsSid, WellKnownSidType.LocalSystemSid })
            acl.AddAccessRule(new FileSystemAccessRule(new SecurityIdentifier(sid, null), FileSystemRights.FullControl, AccessControlType.Allow));
        file.SetAccessControl(acl);
    }

    private static readonly SecurityIdentifier Everyone = new(WellKnownSidType.WorldSid, null);

    public int Denied(string path)
    {
        var item = Item(path);
        if (item is null) return 0;
        var rights = 0;
        foreach (FileSystemAccessRule r in Access(item).GetAccessRules(true, false, typeof(SecurityIdentifier)))
            if (r.AccessControlType == AccessControlType.Deny && Everyone.Equals(r.IdentityReference)) rights |= (int)r.FileSystemRights;
        return rights;
    }

    public void SetDeny(string path, int rights)
    {
        var item = Item(path) ?? throw new FileNotFoundException("not found", path);
        var acl = Access(item);
        foreach (FileSystemAccessRule r in acl.GetAccessRules(true, false, typeof(SecurityIdentifier)))
            if (r.AccessControlType == AccessControlType.Deny && Everyone.Equals(r.IdentityReference)) acl.RemoveAccessRuleSpecific(r);
        if (rights != 0) acl.AddAccessRule(new FileSystemAccessRule(Everyone, (FileSystemRights)rights, AccessControlType.Deny));
        if (item is DirectoryInfo d) d.SetAccessControl((DirectorySecurity)acl); else ((FileInfo)item).SetAccessControl((FileSecurity)acl);
    }

    private static FileSystemInfo? Item(string path) =>
        Directory.Exists(path) ? new DirectoryInfo(path) : File.Exists(path) ? new FileInfo(path) : null;

    private static FileSystemSecurity Access(FileSystemInfo item) => item is DirectoryInfo d
        ? d.GetAccessControl(AccessControlSections.Access)
        : ((FileInfo)item).GetAccessControl(AccessControlSections.Access);
}
