using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Customize.Sound;

/// <summary>src/Tweaks/Customize/Sound/LoudnessEQ.ps1: with the audio services stopped, every playback device's
/// FxProperties gets the value that unhides the Enhancements tab; the services start again whatever happened (an
/// Action: Windows has no hidden state to go back to). A device key that refuses the write is skipped, as
/// -ErrorAction SilentlyContinue skipped it.</summary>
[TweakCode("sound-loudness-eq-tab")]
public sealed class LoudnessEQ : ITweakCode
{
    public const string Render = @"HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render";
    public const string Name = "{d04e05a6-594b-4fb6-a80d-01af5eed7d1d},3";
    public const string Value = "{5860E1C5-F95C-4a7a-8EC8-8AEF24F379A1}";

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var services = FileData.Need(c.Services.Services, "service control");
        if (!services.Stop("audiosrv")) throw new InvalidOperationException("audiosrv did not stop");
        try
        {
            if (!services.Stop("AudioEndpointBuilder")) throw new InvalidOperationException("AudioEndpointBuilder did not stop");
            foreach (var d in c.Registry.SubKeys(Render))
                RegistryTree.Try(() => c.Registry.SetValue($@"{Render}\{d}\FxProperties", Name, Value, "String"));
        }
        finally
        {
            services.Start("AudioEndpointBuilder");
            services.Start("audiosrv");
        }
    }
}
