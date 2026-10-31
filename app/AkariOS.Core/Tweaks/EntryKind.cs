namespace AkariOS.Core.Tweaks;

/// <summary>
/// A data-list Group's kind (ADR 0002), as $AkariEntryKinds in src/Core/Loader.ps1. Rows: every data file row is an
/// Entry (Store apps); otherwise the Entries are what is on this PC, the rows only name and rate them. Reboot: doing it
/// needs a restart. What each kind does is the engine's (N5), not a Tweak's.
/// </summary>
public sealed record EntryKind(string Name, bool Rows, string Button, bool Reboot)
{
    public static readonly EntryKind AppxRemove = new("AppxRemove", Rows: true, "Remove", Reboot: false);
    public static readonly EntryKind CapabilityRemove = new("CapabilityRemove", Rows: false, "Remove", Reboot: true);
    public static readonly EntryKind FeatureDisable = new("FeatureDisable", Rows: false, "Remove", Reboot: true);
    public static readonly EntryKind StoreInstall = new("StoreInstall", Rows: true, "Install", Reboot: false);

    public static IReadOnlyList<EntryKind> All { get; } = [AppxRemove, CapabilityRemove, FeatureDisable, StoreInstall];

    public static EntryKind? Find(string? name) => All.FirstOrDefault(k => string.Equals(k.Name, name, StringComparison.OrdinalIgnoreCase));

    public override string ToString() => Name;
}
