namespace AkariOS.Tweaks;

/// <summary>Marks this assembly for the Loader, which finds the Tweak classes in it (N1).</summary>
public static class TweaksAssembly
{
    public static System.Reflection.Assembly Get() => typeof(TweaksAssembly).Assembly;
}
