using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Runs;

namespace AkariOS.Core.Tweaks;

/// <summary>A Category card of the Guided Tweaks step: its name and Tweak ids.</summary>
public sealed record StepCategory(string Name, IReadOnlyList<string> Ids);

/// <summary>A Section of the Guided Tweaks step: its heading and Category cards.</summary>
public sealed record StepSection(string Section, string Header, IReadOnlyList<StepCategory> Categories);

/// <summary>One pending change of the Guided steps: Apply / Revert, a Choice value other than Recommended, the
/// From → To text Review shows; Hidden = a Tweak the Guided steps don't show (a preset's).</summary>
public sealed record Pending(string Id, string Name, TweakMode Mode, object? Value, bool HasValue, string From, string To, bool Hidden = false);

/// <summary>
/// The rules a selected change goes through (src/UI/Selection.ps1, Steps.ps1 and Cards.ps1, the pure parts): a Choice
/// value's label, the question asked first, the Guided step's Sections, where a row starts, the pending changes. A
/// Selection is an ordered dictionary by Tweak id (its order is Review's).
/// </summary>
public static class Selection
{
    /// <summary>The target of a Toggle or Action being applied (a Choice's target is its value).</summary>
    public const string Optimized = "Optimized";

    /// <summary>A Toggle going back to the Windows default.</summary>
    public const string Default = "Default";

    /// <summary>No change: an unchecked row that started unchecked, a Choice row on "No change".</summary>
    public const string None = "None";

    /// <summary>The Guided Sections, in order ($AkariSectionOrder); others after them by name.</summary>
    public static IReadOnlyList<string> SectionOrder { get; } = ["Optimize", "Customize", "Hardware", "Advanced"];

    private static readonly StringComparer ByName = StringComparer.InvariantCultureIgnoreCase;

    public static int RiskRank(Risk r) => (int)r;

    /// <summary>A Choice value's label, else the value as text (Get-AkariChoiceLabel).</summary>
    public static string ChoiceLabel(Tweak t, object? value)
    {
        var c = t.Choices.FirstOrDefault(c => RegistryEngine.Matches(value, c.Value));
        return c is { Label.Length: > 0 } ? c.Label : $"{value}";
    }

    /// <summary>The question to ask before selecting a target, or null (Get-AkariConfirmText): a Choice value marked
    /// riskier than its Tweak, the Tweak's own Confirm text, or an Advanced Tweak; going back to the Windows default
    /// (a Choice's Default, a Toggle's Revert) never asks.</summary>
    public static string? ConfirmText(Tweak t, object? target, object? windowsDefault)
    {
        if (t.Kind == TweakKind.Choice)
        {
            if (RegistryEngine.Matches(target, windowsDefault)) return null;
            var c = t.Choices.FirstOrDefault(c => RegistryEngine.Matches(target, c.Value));
            if (c?.Risk is { } risk && RiskRank(risk) > RiskRank(t.Risk))
                return $"{t.Name}: '{ChoiceLabel(t, target)}' is marked {risk}. Select it anyway?";
        }
        else if (target as string != Optimized) return null;
        if (!string.IsNullOrEmpty(t.Confirm)) return t.Confirm;
        if (t.Risk == Risk.Advanced) return $"{t.Name} is an Advanced tweak and can break things if you don't know what it does. Select it anyway?";
        return null;
    }

    /// <summary>The Guided Tweaks step's Sections and Category cards (Get-AkariStepGroups, no Legacy): one-file
    /// Toggles, Choices and Actions this PC meets, not Apps, OneClick or Tools, not Guided = $false.</summary>
    public static IReadOnlyList<StepSection> StepGroups(IEnumerable<Tweak> tweaks, ISystemInfo pc)
    {
        var list = tweaks.Where(t => t.Section is not ("Apps" or "OneClick" or "Tools") && t.Guided && t.Group is null && t.EntryKind is null
            && t.Kind is TweakKind.Toggle or TweakKind.Choice or TweakKind.Action && Requirements.Check(t, pc) is null).ToList();
        var sections = list.Select(t => t.Section).Distinct().ToList();
        var ordered = SectionOrder.Where(sections.Contains).Concat(sections.Where(s => !SectionOrder.Contains(s)).OrderBy(s => s, ByName));
        return ordered.Select(s =>
        {
            var inSec = list.Where(t => t.Section == s).ToList();
            var cats = inSec.Select(t => t.Category).Distinct().OrderBy(c => c, ByName);
            return new StepSection(s, Catalogue.HeaderOf(s), cats.Select(c => new StepCategory(c, inSec.Where(t => t.Category == c).Select(t => t.Id).ToList())).ToList());
        }).ToList();
    }

    /// <summary>Where a row starts (Get-AkariRowStart): with "Show current state", an Optimized Toggle checked, a
    /// Choice on its current value when it is one of its values; otherwise unchecked / "No change".</summary>
    public static object RowStart(Tweak t, TweakState state, object? current, bool useState)
    {
        if (!useState) return None;
        return t.Kind switch
        {
            TweakKind.Choice => current is not null && t.Choices.Any(c => RegistryEngine.Matches(c.Value, current)) ? current : None,
            TweakKind.Action => None,
            _ => state == TweakState.Optimized ? Optimized : None,
        };
    }

    /// <summary>A checkbox's target, Win11Debloat's model (Get-AkariCheckTarget): checked = Optimized; unchecking one
    /// that started checked = Default; unchecked and started unchecked = no change.</summary>
    public static string CheckTarget(bool isChecked, object initial) =>
        isChecked ? Optimized : initial as string == Optimized ? Default : None;

    /// <summary>A row's tooltip (Get-AkariRowTip): description, Risk, restart, the State now.</summary>
    public static string RowTip(Tweak t, TweakState state)
    {
        var lines = new List<string?> { t.Description };
        if (t.Risk is Risk.Caution or Risk.Advanced) lines.Add($"Risk: {t.Risk}.");
        if (t.Reboot) lines.Add("Restart required.");
        if (t.Kind != TweakKind.Action)
            lines.Add(state switch { TweakState.Custom => "Now: custom value.", TweakState.Unknown => "Now: state unknown.", _ => $"Now: {state}." });
        return string.Join("\n", lines.Where(l => !string.IsNullOrEmpty(l)));
    }

    /// <summary>The column each card goes in (Get-AkariMasonry): the shortest one so far; a card's size is its rows
    /// (a Choice counts 2), plus 2 for its head.</summary>
    public static IReadOnlyList<int> Masonry(IReadOnlyList<int> sizes, int columns)
    {
        var fill = new int[columns];
        var at = new List<int>();
        foreach (var s in sizes)
        {
            var c = 0;
            for (var i = 1; i < columns; i++) if (fill[i] < fill[c]) c = i;
            fill[c] += s + 2;
            at.Add(c);
        }
        return at;
    }

    /// <summary>Puts a row's target into the Selection, or takes it out (Set-AkariPending). Target: Optimized,
    /// Default or None for a Toggle or Action; a value or None for a Choice. Current: a Choice's value now.</summary>
    public static void SetPending(IDictionary<string, Pending> sel, Tweak t, TweakState state, object? target, object? current, object? windowsDefault)
    {
        sel.Remove(t.Id);
        if (target as string == None) return;
        switch (t.Kind)
        {
            case TweakKind.Choice:
            {
                if (current is not null && RegistryEngine.Matches(current, target)) return;
                var from = state == TweakState.Default ? Default : current is not null ? ChoiceLabel(t, current) : "State unknown";
                if (RegistryEngine.Matches(target, windowsDefault)) sel[t.Id] = new(t.Id, t.Name, TweakMode.Revert, null, false, from, Default);
                else
                {
                    var keep = !RegistryEngine.Matches(target, t.Recommended);
                    sel[t.Id] = new(t.Id, t.Name, TweakMode.Apply, keep ? target : null, keep, from, ChoiceLabel(t, target));
                }
                break;
            }
            case TweakKind.Action:
                // the Action's button word: Run, Remove, Install
                sel[t.Id] = new(t.Id, t.Name, TweakMode.Apply, null, false, "", string.IsNullOrEmpty(t.Button) ? "Run" : t.Button);
                break;
            default:
                var to = target as string ?? "";
                if (to == state.ToString()) return;
                sel[t.Id] = new(t.Id, t.Name, to == Optimized ? TweakMode.Apply : TweakMode.Revert, null, false,
                    state == TweakState.Unknown ? "State unknown" : state.ToString(), to);
                break;
        }
    }

    /// <summary>A number typed into an editable Choice ("0x28", "40"), else null (ConvertFrom-AkariNumber).</summary>
    public static uint? ParseNumber(string text)
    {
        var s = text.Trim();
        if (s.Length is > 2 and <= 10 && s[0] == '0' && s[1] is 'x' or 'X'
            && uint.TryParse(s[2..], System.Globalization.NumberStyles.AllowHexSpecifier, System.Globalization.CultureInfo.InvariantCulture, out var hex)) return hex;
        return uint.TryParse(s, System.Globalization.NumberStyles.Integer, System.Globalization.CultureInfo.InvariantCulture, out var n) ? n : null;
    }

    /// <summary>The Selection as the Runner's items (Get-AkariPlanItems).</summary>
    public static IReadOnlyList<PlanItem> PlanItems(IEnumerable<Pending> sel) =>
        sel.Select(p => new PlanItem(p.Id, p.Mode, p.HasValue ? p.Value : null)).ToList();
}
