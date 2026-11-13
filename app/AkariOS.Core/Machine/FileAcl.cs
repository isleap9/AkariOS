using System.Security.AccessControl;
using System.Security.Principal;

namespace AkariOS.Core.Machine;

/// <summary>Set-AkariAdminOnlyAcl: a file only Administrators and SYSTEM may read or write (inheritance off), made empty
/// when it is missing (what sshd asks of administrators_authorized_keys).</summary>
public interface IFileAcl
{
    void AdminsOnly(string path);
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
}
