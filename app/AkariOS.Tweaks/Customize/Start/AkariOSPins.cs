using System.Text.RegularExpressions;
using AkariOS.Core.Machine;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Start;

/// <summary>
/// src/Tweaks/Customize/Start/AkariOSPins.ps1: Windows 11 keeps the Start pins in the real user's start2.bin, written
/// from the file's Files/start2.txt (base64 in certutil's format) and read back for the State; Start's host stops so it
/// reads them again. Windows 10 loads a layout file once (Files/StartLayout*-Win10.xml): locked, Explorer restarted,
/// unlocked; it can't be read back. Revert = Windows' own pins.
/// </summary>
[TweakCode("start-akarios-pins")]
public sealed partial class AkariOSPins : ITweakCode
{
    private const string Host = "StartMenuExperienceHost";
    private static readonly string[] Policies = [@"HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer", @"HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer"];

    [GeneratedRegex(@"-----[^-]+-----|\s")]
    private static partial Regex Armor();

    /// <summary>AkariOS's start2.bin: the file's Files/start2.txt decoded.</summary>
    public static byte[] Ours(Tweak t, TweakContext c) =>
        Convert.FromBase64String(Armor().Replace(c.Files.ReadText($"{TweakContext.FolderOf(t)}/Files/start2.txt"), ""));

    private static string Bin(TweakContext c) =>
        Path.Combine(FileData.UserFolder(c, "Local AppData"), @"Packages\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy\LocalState\start2.bin");

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        if (c.System.Build < 22000) return TweakState.Unknown;
        var bin = Bin(c);
        if (!File.Exists(bin)) return TweakState.Default;
        return File.ReadAllBytes(bin).AsSpan().SequenceEqual(Ours(tweak, c)) ? TweakState.Optimized : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        if (c.System.Build >= 22000)
        {
            var bin = Bin(c);
            Directory.CreateDirectory(Path.GetDirectoryName(bin)!);
            File.WriteAllBytes(bin, Ours(tweak, c));
            // Start reads it when it starts; Windows starts it again by itself
            FileData.Need(c.Services.Processes, "process control").Stop(Host);
            return;
        }
        Win10Layout(tweak, c, "StartLayoutEmpty-Win10.xml");
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        if (c.System.Build >= 22000)
        {
            // no start2.bin: Start builds Windows' default pins again
            try { File.Delete(Bin(c)); } catch (Exception e) when (e is IOException or UnauthorizedAccessException) { c.Log.Write($"Warning: start2.bin kept ({e.Message})"); }
            FileData.Need(c.Services.Processes, "process control").Stop(Host);
            return;
        }
        Win10Layout(tweak, c, "StartLayoutDefault-Win10.xml");
    }

    // Windows 10: lock the layout file, let Explorer load it, then unlock it so the user can pin again
    private static void Win10Layout(Tweak tweak, TweakContext c, string layout)
    {
        var s = c.Services;
        var xml = Path.Combine(TweakServices.Folder(s.Windows, "Windows"), "StartMenuLayout.xml");
        File.WriteAllBytes(xml, c.Files.ReadBytes($"{TweakContext.FolderOf(tweak)}/Files/{layout}"));
        foreach (var k in Policies)
        {
            c.Registry.SetValue(k, "LockedStartLayout", 1, "DWord");
            c.Registry.SetValue(k, "StartLayoutFile", xml, "ExpandString");
        }
        FileData.Need(s.Explorer, "Explorer").Restart();
        s.Sleep(TimeSpan.FromSeconds(5));
        foreach (var k in Policies)
        {
            c.Registry.SetValue(k, "LockedStartLayout", 0, "DWord");
            c.Registry.RemoveValue(k, "StartLayoutFile");
        }
        try { File.Delete(xml); } catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
    }
}
