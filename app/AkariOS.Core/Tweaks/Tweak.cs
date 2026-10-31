using AkariOS.Core.Data;

namespace AkariOS.Core.Tweaks;

public enum TweakKind { Toggle, Choice, Action, Group }

public enum Risk { Safe, Caution, Advanced }

/// <summary>A value per Windows version: one value for both, or <c>@{ Win10 = ...; Win11 = ... }</c>.</summary>
public sealed record OsValue(object? Win10, object? Win11)
{
    public static OsValue Both(object? v) => new(v, v);

    public bool PerOs => !Equals(Win10, Win11);

    /// <summary>The value for a build: Windows 11 from build 22000.</summary>
    public object? For(int build) => build >= 22000 ? Win11 : Win10;
}

/// <summary>
/// One row of a Tweak's Registry: a value row (Name set; '(default)' = the key's unnamed value) or a key row (Name
/// null: Value / Default are 'Key' = the key exists, null = the key is deleted with its contents). Value as PsData
/// read it (a Binary value is a byte[]); Default null = the value is deleted on Revert.
/// </summary>
public sealed record RegistryRow(string Path, string? Name, string? Type, object? Value, OsValue Default, bool IsKeyRow);

/// <summary>One value a Choice offers (its own Risk, else the Tweak's).</summary>
public sealed record ChoiceValue(object? Value, string Label, Risk? Risk);

/// <summary>A problem the Loader found in a file. Level: Error (the file is left out) or Warning.</summary>
public sealed record Problem(string File, string Level, string Message);

/// <summary>
/// A Tweak as the Loader builds it from its src/Tweaks file (docs/PLAN.md §7), or an Entry built from a data-list
/// Group's row. The fields are the file's; Blocks names its script blocks (Apply, Revert, Detect, Check, Before,
/// After, Prepare, Value), which the native app never runs: <see cref="Code"/> is the C# that does their job.
/// </summary>
public sealed class Tweak
{
    public required string Id { get; init; }
    public required string Name { get; init; }
    public string? Description { get; init; }
    public required string Section { get; init; }
    public required string Category { get; init; }
    public TweakKind Kind { get; init; } = TweakKind.Toggle;
    public Risk Risk { get; init; }
    public string Button { get; init; } = "Run";
    public string? Confirm { get; init; }
    public bool Reboot { get; init; }
    public bool SafeMode { get; init; }
    public bool Restarts { get; init; }
    public bool Explorer { get; init; }
    public bool AkariOS { get; init; }
    public bool Guided { get; init; } = true;
    public bool Editable { get; init; }
    public IReadOnlyList<string> Requires { get; init; } = [];

    /// <summary>The rows, or null with no Registry. A row PsData kept as code (a foreach) is left out: see RowsAreCode.</summary>
    public IReadOnlyList<RegistryRow>? Registry { get; init; }
    public bool RowsAreCode { get; init; }

    public IReadOnlyList<ChoiceValue> Choices { get; init; } = [];
    public object? Recommended { get; init; }
    public object? Default { get; init; }

    public IReadOnlyList<string> Winget { get; init; } = [];
    public string? WingetSource { get; init; }
    public string? AppType { get; init; }
    public string? StoreId { get; init; }

    /// <summary>Entries: the Group's id, the package or feature name, the keep-list mark.</summary>
    public string? Group { get; init; }
    public string? Package { get; init; }

    /// <summary>An Entry's kind (what the engine does to it), from its Group.</summary>
    public EntryKind? EntryKind { get; init; }
    public bool Keep { get; init; }

    /// <summary>The script blocks the file has, by field name.</summary>
    public IReadOnlySet<string> Blocks { get; init; } = new HashSet<string>();

    /// <summary>True when the file needs code: a script block, or a value PsData kept as code.</summary>
    public bool NeedsCode { get; init; }

    /// <summary>The C# for a Tweak that needs code (AkariOS.Tweaks), or null: then only the PowerShell app can run it.</summary>
    public ITweakCode? Code { get; init; }

    /// <summary>Its file, as a src/ path ("src/Tweaks/Optimize/Gaming/CaptureOff.ps1").</summary>
    public required string Source { get; init; }

    /// <summary>The file's fields as PsData read them.</summary>
    public PsHashtable Fields { get; init; } = new();

    /// <summary>The native app can run it: no code needed, or its C# is there.</summary>
    public bool Native => !NeedsCode || Code is not null;

    public bool Has(string block) => Blocks.Contains(block);

    public override string ToString() => Id;
}

/// <summary>A data-list Group (ADR 0002): its Entries come from its data file's Rows through its EntryKind.</summary>
public sealed class TweakGroup
{
    public required string Id { get; init; }
    public required string Name { get; init; }
    public string? Description { get; init; }
    public required string Section { get; init; }
    public required string Category { get; init; }
    public Risk Risk { get; init; }
    public required EntryKind EntryKind { get; init; }
    public IReadOnlyList<PsHashtable> Rows { get; init; } = [];
    public IReadOnlyList<string> KeepNames { get; init; } = [];
    public string? AppType { get; init; }
    public required string Source { get; init; }

    public override string ToString() => Id;
}

/// <summary>What the Loader read: the Tweaks (Entries of row Groups included), the Groups, the Problems.</summary>
public sealed record LoadResult(IReadOnlyList<Tweak> Tweaks, IReadOnlyList<TweakGroup> Groups, IReadOnlyList<Problem> Problems)
{
    public Tweak? Find(string id) => Tweaks.FirstOrDefault(t => t.Id == id);
}
