using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Optimize.Performance;

/// <summary>src/Tweaks/Optimize/Performance/BitLocker.ps1: decrypts every volume that is protected or not fully
/// decrypted (an Action: turning BitLocker back on needs the user's own choices). Done = none left, or no BitLocker
/// on this edition.</summary>
[TweakCode("performance-bitlocker-off")]
public sealed class BitLocker : ITweakCode
{
    private static IReadOnlyList<BitLockerVolume>? Left(TweakContext c) =>
        FileData.Need(c.Services.BitLocker, "BitLocker").Volumes()?.Where(v => v.ProtectionOn || !v.FullyDecrypted).ToList();

    public TweakState Detect(Tweak tweak, TweakContext c) =>
        Left(c) is not { Count: > 0 } ? TweakState.Optimized : TweakState.Default;

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        if (Left(c) is not { } left) { c.Log.Write("BitLocker is not on this edition of Windows"); return; }
        foreach (var v in left)
        {
            // -ErrorAction SilentlyContinue: one volume that won't start doesn't stop the others
            try
            {
                FileData.Need(c.Services.BitLocker, "BitLocker").Decrypt(v);
                c.Log.Write($"Decrypting {v.MountPoint}");
            }
            catch (Exception e) when (e is System.Management.ManagementException or UnauthorizedAccessException) { c.Log.Write($"Warning: {v.MountPoint}: {e.Message}"); }
        }
    }
}
