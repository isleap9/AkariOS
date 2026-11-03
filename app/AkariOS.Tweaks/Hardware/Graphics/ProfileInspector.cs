using AkariOS.Core.Machine;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Hardware.Graphics;

/// <summary>
/// The steps the two NVIDIA profile Tweaks share (NvidiaSettings.ps1, ReBarForce.ps1): the driver's profile files
/// unblocked (Unblock-File), NVIDIA Profile Inspector downloaded from AkariOS-Files when it is missing (Save-AkariFile),
/// its Start menu shortcut (New-AkariShortcut), and a .nip from the Tweak's Files folder imported silently, waiting for
/// it. The .nip is written out to the Files folder first: the native app carries src/ inside the exe.
/// </summary>
public static class ProfileInspector
{
    public const string Download = "inspector.exe";
    public const string Name = "Nvidia Profile Inspector";

    public static string Exe(TweakContext c) =>
        Path.Combine(TweakServices.Folder(c.Services.ProgramFilesX86, "Program Files (x86)"), Name, $"{Name}.exe");

    /// <summary>The Mark of the Web taken off every file of the driver's profile store (ProgramData\NVIDIA
    /// Corporation\Drs); a missing folder is nothing to do.</summary>
    public static void UnblockDrs(TweakContext c)
    {
        var drs = Path.Combine(TweakServices.Folder(c.Services.ProgramData, "ProgramData"), "NVIDIA Corporation", "Drs");
        if (!Directory.Exists(drs)) return;
        foreach (var f in Directory.EnumerateFiles(drs, "*", SearchOption.AllDirectories))
            try { File.Delete($"{f}:Zone.Identifier"); }
            catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
    }

    /// <summary>The program, downloaded when it is missing; its path.</summary>
    public static string Ensure(TweakContext c)
    {
        var exe = Exe(c);
        if (!File.Exists(exe)) FileData.Need(c.Services.Downloads, "downloads").Save(Download, exe);
        return exe;
    }

    public static void Shortcut(TweakContext c, string exe)
    {
        var programs = Path.Combine(TweakServices.Folder(c.Services.ProgramData, "ProgramData"), @"Microsoft\Windows\Start Menu\Programs");
        FileData.Need(c.Services.Shortcuts, "shortcuts").Create(Path.Combine(programs, $"{Name}.lnk"), exe, Path.GetDirectoryName(exe));
    }

    /// <summary>Imports Files\&lt;nip&gt; of the Tweak's folder (merge: into the profiles, not replacing them).</summary>
    public static void Import(Tweak tweak, TweakContext c, string exe, string nip, bool merge = false)
    {
        var folder = TweakServices.Folder(c.Services.FilesFolder, "Files");
        Directory.CreateDirectory(folder);
        var file = Path.Combine(folder, nip);
        File.WriteAllBytes(file, c.Files.ReadBytes($"{TweakContext.FolderOf(tweak)}/Files/{nip}"));
        FileData.Need(c.Services.Exe, "program runner").Run(exe, $"-silentImport {(merge ? "-mergeImport " : "")}-silent \"{file}\"");
    }
}
