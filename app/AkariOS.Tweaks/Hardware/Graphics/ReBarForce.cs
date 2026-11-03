using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Hardware.Graphics;

/// <summary>
/// src/Tweaks/Hardware/Graphics/ReBarForce.ps1: rBAR on in the driver's Base Profile (Files\nvidia-rebar-on.nip, a
/// merge import with NVIDIA Profile Inspector). The profile can't be read back: Detect is what Akari last did
/// (state.json), which Apply and Revert write. Revert imports the whole Base Profile again: FR33THY's when
/// graphics-nvidia-settings' registry part is there, else the empty one.
/// </summary>
[TweakCode("graphics-nvidia-rebar-force")]
public sealed class ReBarForce : ITweakCode
{
    public TweakState Detect(Tweak tweak, TweakContext c) =>
        FileData.Need(c.Services.Remembered, "remembered state").Get(tweak.Id) == true ? TweakState.Optimized : TweakState.Default;

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        ProfileInspector.UnblockDrs(c);
        var exe = ProfileInspector.Ensure(c);
        ProfileInspector.Shortcut(c, exe);
        ProfileInspector.Import(tweak, c, exe, "nvidia-rebar-on.nip", merge: true);
        FileData.Need(c.Services.Remembered, "remembered state").Set(tweak.Id, true);
    }

    public void Revert(Tweak tweak, TweakContext c, object? value)
    {
        ProfileInspector.UnblockDrs(c);
        var exe = ProfileInspector.Ensure(c);
        var nip = NvidiaSettings.Fr33thy(c) ? "nvidia-base-profile.nip" : "nvidia-default-profile.nip";
        ProfileInspector.Import(tweak, c, exe, nip);
        FileData.Need(c.Services.Remembered, "remembered state").Set(tweak.Id, false);
    }
}
