using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Start;

/// <summary>src/Tweaks/Customize/Start/HideAccessibilityFolders.ps1: the user's and all users' Accessibility folders and
/// Windows Accessories hidden (attrib +h), everything in them too; like attrib, System files (desktop.ini) keep theirs.</summary>
[TweakCode("start-hide-accessibility-folders")]
public sealed class HideAccessibilityFolders : ITweakCode
{
    private static IReadOnlyList<string> Folders(TweakContext c)
    {
        var common = Path.Combine(TweakServices.Folder(c.Services.ProgramData, "ProgramData"), @"Microsoft\Windows\Start Menu\Programs");
        return new[] { Path.Combine(FileData.UserFolder(c, "Programs"), "Accessibility"), Path.Combine(common, "Accessibility"), Path.Combine(common, "Accessories") }
            .Where(Directory.Exists).ToList();
    }

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var dirs = Folders(c);
        if (dirs.Count == 0) return TweakState.Unknown;
        var hidden = dirs.Count(d => new DirectoryInfo(d).Attributes.HasFlag(FileAttributes.Hidden));
        return hidden == dirs.Count ? TweakState.Optimized : hidden == 0 ? TweakState.Default : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value) => Set(c, hide: true);

    public void Revert(Tweak tweak, TweakContext c, object? value) => Set(c, hide: false);

    private static void Set(TweakContext c, bool hide)
    {
        foreach (var d in Folders(c))
        {
            var items = new List<FileSystemInfo> { new DirectoryInfo(d) };
            items.AddRange(new DirectoryInfo(d).EnumerateFileSystemInfos("*", SearchOption.AllDirectories));
            foreach (var i in items.Where(i => !i.Attributes.HasFlag(FileAttributes.System)))
                i.Attributes = hide ? i.Attributes | FileAttributes.Hidden : i.Attributes & ~FileAttributes.Hidden;
        }
    }
}
