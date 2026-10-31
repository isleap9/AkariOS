using System.Reflection;
using AkariOS.Core.Registry;
using AkariOS.Core.Sources;
using AkariOS.Core.Machine;

namespace AkariOS.Core.Tweaks;

/// <summary>What a Tweak's C# works with: the registry, the machine, the shared files, its own file's folder.</summary>
public sealed class TweakContext(RegistryEngine registry, ISystemInfo system, ISourceFiles files, IAkariLog? log = null)
{
    public RegistryEngine Registry { get; } = registry;
    public ISystemInfo System { get; } = system;
    public ISourceFiles Files { get; } = files;

    /// <summary>What a block would have written to the log.</summary>
    public IAkariLog Log { get; } = log ?? new MemoryLog();

    /// <summary>The src/ folder of a Tweak's file ($AkariTweakDir): its Files/ are next to it.</summary>
    public static string FolderOf(Tweak t) => SourceFilesExtensions.Folder(t.Source);
}

/// <summary>
/// The C# behind a Tweak whose src/Tweaks file has script blocks (ADR 0007): one class per Tweak in AkariOS.Tweaks,
/// marked [TweakCode("its-id")]; its metadata stays in the file. A class gives what its file's blocks do, nothing
/// else: the members it doesn't override are never called for it.
/// </summary>
public interface ITweakCode
{
    /// <summary>The file's Detect block: the State (a Toggle), done or not (an Action). Throwing = Unknown.</summary>
    TweakState Detect(Tweak tweak, TweakContext c) => throw new NotSupportedException($"{tweak.Id} has no Detect in C#");

    /// <summary>A Choice's Value block: its current value, null = none of its values (Custom).</summary>
    object? ChoiceValue(Tweak tweak, TweakContext c) => throw new NotSupportedException($"{tweak.Id} has no ChoiceValue in C#");

    /// <summary>The Registry rows a file builds with code (a foreach, a helper block): all of them.</summary>
    IReadOnlyList<RegistryRow> Rows(Tweak tweak, TweakContext c) => throw new NotSupportedException($"{tweak.Id} has no Rows in C#");

    /// <summary>The file's Apply block. Value: a Choice over many settings' picked value ($AkariValue).</summary>
    void Apply(Tweak tweak, TweakContext c, object? value) => throw new NotSupportedException($"{tweak.Id} has no Apply in C#");

    /// <summary>The file's Revert block. Value: a Choice over many settings' Windows default.</summary>
    void Revert(Tweak tweak, TweakContext c, object? value) => throw new NotSupportedException($"{tweak.Id} has no Revert in C#");

    /// <summary>A registry Toggle's After block: one more step after its rows, both ways ($AkariMode).</summary>
    void After(Tweak tweak, TweakContext c, TweakMode mode) => throw new NotSupportedException($"{tweak.Id} has no After in C#");

    /// <summary>A SafeMode Tweak's Prepare block, in normal mode before the restart into Safe Mode (a download).</summary>
    void Prepare(Tweak tweak, TweakContext c) => throw new NotSupportedException($"{tweak.Id} has no Prepare in C#");
}

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
