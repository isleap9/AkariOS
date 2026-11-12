using System.Text;
using AkariOS.Core.Machine;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Apps.Install;

// Steps the installs share (src/Tweaks/Apps/Install/*.ps1).

/// <summary>A Chromium browser's policies (Brave, Chrome, Helium): no hardware acceleration, no background mode,
/// efficiency mode on; uBlock Origin Lite forced in where the file adds it.</summary>
internal static class ChromiumPolicies
{
    /// <summary>uBlock Origin Lite from the Chrome Web Store.</summary>
    public const string UBlockLite = "ddkjiahejlhfcafbddmgiahcphecmpfh;https://clients2.google.com/service/update2/crx";

    public static void Set(TweakContext c, string key, bool uBlock)
    {
        if (uBlock) c.Registry.SetValue($@"{key}\ExtensionInstallForcelist", "1", UBlockLite, "String");
        c.Registry.SetValue(key, "HardwareAccelerationModeEnabled", 0, "DWord");
        c.Registry.SetValue(key, "BackgroundModeEnabled", 0, "DWord");
        c.Registry.SetValue(key, "HighEfficiencyModeEnabled", 1, "DWord");
    }
}

/// <summary>A program from the AkariOS-Files release (Save-AkariFile), not on winget.</summary>
internal static class Download
{
    /// <summary>A path under Program Files (x86).</summary>
    public static string X86(TweakContext c, string relative) => Path.Combine(AppFiles.Folder(c.Services.ProgramFilesX86, "Program Files (x86)"), relative);

    /// <summary>A path under %SystemRoot% (an installer goes to its Temp).</summary>
    public static string Windows(TweakContext c, string relative) => Path.Combine(AppFiles.Folder(c.Services.Windows, "Windows"), relative);

    /// <summary>Done when every file is there (Test-Path).</summary>
    public static TweakState Done(params string[] files) => files.All(File.Exists) ? TweakState.Optimized : TweakState.Default;

    /// <summary>Downloads it to the path; returns the path.</summary>
    public static string Save(TweakContext c, string name, string outFile)
    {
        TweakServices.Need(c.Services.Downloads, "AkariOS-Files downloader").Save(name, outFile);
        return outFile;
    }

    /// <summary>A single-exe tool: downloaded, with a Start menu shortcut.</summary>
    public static void Tool(TweakContext c, string shortcut, string name, string outFile) => AkariOS.Core.Apps.AppSetup.Shortcut(c, shortcut, Save(c, name, outFile));

    /// <summary>An installer: downloaded and run (Start-Process -Wait: its own window, waited for alone).</summary>
    public static void Install(TweakContext c, string name, string outFile, string arguments = "") =>
        TweakServices.Need(c.Services.Exe, "program runner").Run(Save(c, name, outFile), arguments, wait: true, capture: false);
}

/// <summary>Files an install writes or copies.</summary>
internal static class AppFiles
{
    /// <summary>Set-Content -Value '&lt;text&gt;' in 5.1: the text and a line break, ANSI (the texts are ASCII), CRLF
    /// line breaks (the release's .ps1 files have them); the folder made first.</summary>
    public static void WriteText(string file, string text)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(file)!);
        File.WriteAllBytes(file, Encoding.ASCII.GetBytes(text.ReplaceLineEndings("\r\n") + "\r\n"));
    }

    /// <summary>Copy-Item -Recurse -Force of the Tweak's Files/&lt;folder&gt; (its src/ copy, byte for byte) into the
    /// destination: every file under it at the same place below the destination, folders made, files replaced.</summary>
    public static void CopyFolder(Tweak tweak, TweakContext c, string folder, string destination)
    {
        var from = $"{TweakContext.FolderOf(tweak)}/Files/{folder}/";
        foreach (var f in c.Files.List(from))
        {
            var to = Path.Combine(destination, f[from.Length..].Replace('/', '\\'));
            Directory.CreateDirectory(Path.GetDirectoryName(to)!);
            File.WriteAllBytes(to, c.Files.ReadBytes(f));
        }
    }

    /// <summary>A file of the Tweak's Files/ (its src/ copy) written to a path.</summary>
    public static void CopyFile(Tweak tweak, TweakContext c, string file, string to)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(to)!);
        File.WriteAllBytes(to, c.Files.ReadBytes($"{TweakContext.FolderOf(tweak)}/Files/{file}"));
    }

    /// <summary>The real user's folder (Get-AkariUserFolder).</summary>
    public static string User(TweakContext c, string name) => FileData.UserFolder(c, name);

    /// <summary>A folder of the engine's (Program Files (x86), Public…), or a failure when it has none.</summary>
    public static string Folder(string folder, string what) => TweakServices.Folder(folder, what);
}
