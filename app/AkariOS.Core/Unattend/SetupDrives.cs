namespace AkariOS.Core.Unattend;

/// <summary>A drive a setup file can go on: its root (E:\), its label, and whether it holds Windows setup.</summary>
public sealed record SetupDrive(string Root, string Label, bool Setup);

/// <summary>The drives a setup file can go on (Get-AkariSetupDrives; the real one reads this PC, tests fake it).</summary>
public interface ISetupDrives
{
    IReadOnlyList<SetupDrive> All();
}

/// <summary>Get-AkariSetupDrives and the page's drive list (Update-AkariUnattendDrives).</summary>
public static class SetupDrives
{
    private static readonly string[] Images = ["install.wim", "install.esd", "install.swm"];

    /// <summary>Removable drives, and any other local disk holding Windows setup (a USB SSD shows as fixed); never
    /// the system drive.</summary>
    public static IReadOnlyList<SetupDrive> Pick(IEnumerable<(string Root, DriveType Type, string Label)> drives, string systemDrive, Func<string, bool> exists)
    {
        var list = new List<SetupDrive>();
        foreach (var (root, type, label) in drives)
        {
            if (string.Equals(root.TrimEnd('\\'), systemDrive.TrimEnd('\\'), StringComparison.OrdinalIgnoreCase)) continue;
            if (type is not (DriveType.Removable or DriveType.Fixed)) continue;
            var setup = Images.Any(i => exists(Path.Combine(root, "sources", i)));
            if (type == DriveType.Removable || setup) list.Add(new SetupDrive(root, label, setup));
        }
        return list;
    }

    /// <summary>The drives with Windows setup first (the first is picked).</summary>
    public static IReadOnlyList<SetupDrive> Ordered(IEnumerable<SetupDrive> drives) => [.. drives.Where(d => d.Setup), .. drives.Where(d => !d.Setup)];

    /// <summary>"E:\ LABEL (Windows setup)".</summary>
    public static string Display(SetupDrive d)
    {
        var name = d.Label.Length > 0 ? $"{d.Root} {d.Label}" : d.Root;
        return d.Setup ? $"{name} (Windows setup)" : name;
    }
}

/// <summary>This PC's drives (guarded: never under test).</summary>
public sealed class LiveSetupDrives : ISetupDrives
{
    public LiveSetupDrives() => SystemGuard.Check("The drive list");

    public IReadOnlyList<SetupDrive> All() => SetupDrives.Pick(
        DriveInfo.GetDrives().Select(d => (d.Name, d.DriveType, Label(d))),
        Environment.GetEnvironmentVariable("SystemDrive") ?? "C:",
        File.Exists);

    /// <summary>A drive with no media (a card reader) has no label.</summary>
    private static string Label(DriveInfo d)
    {
        try { return d.IsReady ? d.VolumeLabel : ""; }
        catch (IOException) { return ""; }
        catch (UnauthorizedAccessException) { return ""; }
    }
}

/// <summary>Save-AkariUnattend: autounattend.xml in a folder.</summary>
public static class UnattendSave
{
    public const string FileName = "autounattend.xml";

    /// <summary>Writes the file in <paramref name="folder"/> (made if missing; an existing file is replaced: the page
    /// asks first) and returns its path.</summary>
    public static string Save(byte[] bytes, string folder)
    {
        Directory.CreateDirectory(folder);
        var path = Path.Combine(folder, FileName);
        File.WriteAllBytes(path, bytes);
        return path;
    }

    public static bool Exists(string folder) => File.Exists(Path.Combine(folder, FileName));
}
