using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks;

/// <summary>This assembly's Tweak classes ([TweakCode("id")], one per src/Tweaks file that has code), for the Loader.</summary>
public static class TweaksAssembly
{
    public static System.Reflection.Assembly Get() => typeof(TweaksAssembly).Assembly;

    private static readonly Lazy<IReadOnlyDictionary<string, ITweakCode>> Lazy = new(() => TweakCodes.From(Get()));

    public static IReadOnlyDictionary<string, ITweakCode> Codes => Lazy.Value;
}
