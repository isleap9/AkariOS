using AkariOS.Core.Registry;

namespace AkariOS.Core.Tweaks;

/// <summary>
/// The rules a selected change goes through before it runs (src/UI/Selection.ps1, pure): a Choice value's label,
/// and the question asked first. Shared by the Catalogue (a change acting right away) and Guided (batch d).
/// </summary>
public static class Selection
{
    /// <summary>The target of a Toggle or Action being applied (a Choice's target is its value).</summary>
    public const string Optimized = "Optimized";

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
}
