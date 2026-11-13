using System.Management;

namespace AkariOS.Core.Iso;

/// <summary>
/// The real <see cref="IDiskImage"/> (guarded): the ISO mounted read-only through WMI's MSFT_DiskImage (as
/// Mount-DiskImage), its drive found through MSFT_DiskImageToVolume (as Get-Volume), dismounted after.
/// </summary>
public sealed class WmiDiskImage : IDiskImage
{
    private const string Storage = @"root\Microsoft\Windows\Storage";
    private const int Iso = 1, ReadOnly = 3;

    public WmiDiskImage() => SystemGuard.Check("disk image");

    /// <summary>A WQL string literal: backslashes doubled, quotes escaped.</summary>
    public static string Literal(string text) => "'" + text.Replace(@"\", @"\\").Replace("'", @"\'") + "'";

    private static ManagementObject? Image(string iso)
    {
        using var s = new ManagementObjectSearcher(new ManagementScope(Storage),
            new ObjectQuery($"SELECT * FROM MSFT_DiskImage WHERE ImagePath = {Literal(Path.GetFullPath(iso))} AND StorageType = {Iso}"));
        return s.Get().Cast<ManagementObject>().FirstOrDefault();
    }

    public string Mount(string iso)
    {
        using var image = Image(iso) ?? throw new IsoException($"Windows can't open {iso} as a disk image.");
        var args = image.GetMethodParameters("Mount");
        args["Access"] = (ushort)ReadOnly;
        args["NoDriveLetter"] = false;
        using (image.InvokeMethod("Mount", args, null)) { }
        // the volume shows up a moment after the mount
        for (var i = 0; i < 20; i++)
        {
            if (DriveOf(iso) is { } root) return root;
            Thread.Sleep(500);
        }
        Dismount(iso);
        throw new IsoException($"{iso} was mounted but Windows gave it no drive letter.");
    }

    private static string? DriveOf(string iso)
    {
        using var image = Image(iso);
        if (image is null) return null;
        foreach (var v in image.GetRelated("MSFT_Volume", "MSFT_DiskImageToVolume", null, null, null, null, false, null).Cast<ManagementObject>())
            using (v)
                if (v["DriveLetter"] is char c && c != '\0') return $@"{c}:\";
        return null;
    }

    public void Dismount(string iso)
    {
        try
        {
            using var image = Image(iso);
            if (image is null) return;
            using (image.InvokeMethod("Dismount", null, null)) { }
        }
        catch (ManagementException) { }
    }
}
