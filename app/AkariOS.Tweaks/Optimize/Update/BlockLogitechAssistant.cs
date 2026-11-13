using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Update;

/// <summary>src/Tweaks/Optimize/Update/BlockLogitechAssistant.ps1 (winutil W3): the Logi Download Assistant stopped, its
/// Program Files folder emptied (made when missing) and Everyone denied writing to it (mask 278); Revert lifts the deny
/// and leaves the folder.</summary>
[TweakCode("update-block-logitech-assistant")]
public sealed class BlockLogitechAssistant : ITweakCode
{
    private const int Write = 278;

    private static string Folder(TweakContext c) =>
        Path.Combine(TweakServices.Folder(c.Services.ProgramFiles, "Program Files"), "LogiDownloadAssistant");

    private static IFileAcl Acl(TweakContext c) => FileData.Need(c.Services.Acl, "file permissions");

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var r = Acl(c).Denied(Folder(c));
        return (r & Write) == Write ? TweakState.Optimized : r == 0 ? TweakState.Default : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var p = Folder(c);
        FileData.Need(c.Services.Processes, "processes").Stop("logi_download_assistant");
        if (Directory.Exists(p))
        {
            foreach (var d in Directory.EnumerateDirectories(p)) Directory.Delete(d, recursive: true);
            foreach (var f in Directory.EnumerateFiles(p)) File.Delete(f);
        }
        else Directory.CreateDirectory(p);
        Acl(c).SetDeny(p, Write);
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        var p = Folder(c);
        if (Directory.Exists(p)) Acl(c).SetDeny(p, 0);
    }
}
