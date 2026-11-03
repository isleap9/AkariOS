using AkariOS.Core.Machine;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Network;

/// <summary>src/Tweaks/Optimize/Network/BlockRazerAsus.ps1: ZOICWARE's Razer and ASUS hosts lines in Akari's own
/// "razer-asus" block of the hosts file, so Revert removes exactly them. The host names are read from the file's
/// Files/RazerAsusHosts.ps1 ($hosts), as Get-AkariRazerAsusHosts writes them: "0.0.0.0 &lt;host&gt;".</summary>
[TweakCode("network-block-razer-asus")]
public sealed class BlockRazerAsus : ITweakCode
{
    private const string Block = "razer-asus";

    public static IReadOnlyList<string> Lines(Tweak tweak, TweakContext c) =>
        FileData.AssignedList(c.Files, $"{TweakContext.FolderOf(tweak)}/Files/RazerAsusHosts.ps1", "hosts").Select(h => $"0.0.0.0 {h}").ToList();

    public TweakState Detect(Tweak tweak, TweakContext c)
    {
        var have = HostsBlocks.Get(FileData.Need(c.Services.Hosts, "hosts file").Read(), Block);
        if (have is null) return TweakState.Default;
        return have.SequenceEqual(Lines(tweak, c), StringComparer.Ordinal) ? TweakState.Optimized : TweakState.Custom;
    }

    public void Apply(Tweak tweak, TweakContext c, object? value) => Write(c, Lines(tweak, c));

    public void Revert(Tweak tweak, TweakContext c, object? value) => Write(c, []);

    private static void Write(TweakContext c, IReadOnlyList<string> lines)
    {
        var hosts = FileData.Need(c.Services.Hosts, "hosts file");
        hosts.Write(HostsBlocks.Set(hosts.Read(), Block, lines));
    }
}
