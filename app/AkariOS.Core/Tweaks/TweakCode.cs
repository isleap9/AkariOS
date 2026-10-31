using System.Reflection;

namespace AkariOS.Core.Tweaks;

/// <summary>
/// The C# behind a Tweak whose src/Tweaks file has script blocks (ADR 0007): one class per Tweak in AkariOS.Tweaks,
/// marked [TweakCode("its-id")]. Its metadata stays in the file. What a class provides (Detect, Apply, Revert, rows)
/// is added with the State and Runner batches of N1.
/// </summary>
public interface ITweakCode;

[AttributeUsage(AttributeTargets.Class, AllowMultiple = false)]
public sealed class TweakCodeAttribute(string id) : Attribute
{
    public string Id { get; } = id;
}

/// <summary>The Tweak classes of an assembly, by id.</summary>
public static class TweakCodes
{
    /// <summary>Every [TweakCode] class of the assembly, made once. Two classes for one id throw.</summary>
    public static IReadOnlyDictionary<string, ITweakCode> From(Assembly assembly)
    {
        var map = new Dictionary<string, ITweakCode>(StringComparer.Ordinal);
        foreach (var type in assembly.GetTypes().Where(t => t is { IsClass: true, IsAbstract: false }))
        {
            var attr = type.GetCustomAttribute<TweakCodeAttribute>();
            if (attr is null) continue;
            if (!typeof(ITweakCode).IsAssignableFrom(type)) throw new InvalidOperationException($"{type.Name} has [TweakCode] but is not an ITweakCode");
            if (map.ContainsKey(attr.Id)) throw new InvalidOperationException($"two classes for '{attr.Id}': {map[attr.Id].GetType().Name} and {type.Name}");
            map[attr.Id] = (ITweakCode)Activator.CreateInstance(type)!;
        }
        return map;
    }
}
