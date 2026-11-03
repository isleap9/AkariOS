using System.Windows;
using System.Windows.Controls;
using AkariOS.App.Look;
using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;

namespace AkariOS.App.Pages;

/// <summary>
/// Guided's Review &amp; Apply step and its result screen (src/UI/Steps.ps1): the pending changes as review rows
/// (From → To), those to Tweaks only Optimize › Advanced shows under their own heading, the note about changes that
/// restart the PC; then one row per Outcome under the Run's counts.
/// </summary>
public static class ReviewStep
{
    /// <summary>The Review step's body.</summary>
    public static StackPanel Review(IEnumerable<Pending> sel, Func<string, Tweak?> find)
    {
        var panel = new StackPanel();
        var items = sel.ToList();
        // changes that restart the PC run last (the Runner): say so before Apply
        if (Selection.RestartNote(items, find) is { } note)
        {
            var n = Parts.Text(note, 13, "Warn");
            n.Margin = new Thickness(0, 0, 0, 12);
            panel.Children.Add(n);
        }
        var hidden = items.Where(p => p.Hidden).ToList();
        foreach (var p in items.Where(p => !p.Hidden).Concat(hidden))
        {
            if (hidden.Count > 0 && p == hidden[0])
            {
                var hd = Parts.Title("Advanced settings (Optimize › Advanced)", 16);
                hd.Margin = new Thickness(2, 12, 0, 8);
                panel.Children.Add(hd);
            }
            var change = p.From.Length > 0 ? $"{p.From} → {p.To}" : p.To;
            var (icon, brush) = p.To == Selection.Default ? ("undo-2", "Mu") : ("arrow-right", "AccText");
            panel.Children.Add(Row(p.Id, p.Name, change, icon, brush, find));
        }
        return panel;
    }

    /// <summary>The result screen (Show-AkariResult): the counts, "Restart Windows to finish." when needed, a row per
    /// Outcome with its message.</summary>
    public static StackPanel Result(IReadOnlyList<Outcome> outcomes, Func<string, Tweak?> find)
    {
        var panel = new StackPanel();
        var (text, reboot) = Selection.RunSummary(outcomes);
        var head = Parts.Text(text, 14);
        head.Margin = new Thickness(0, 0, 0, 12);
        panel.Children.Add(head);
        if (reboot)
        {
            var rb = Parts.Text("Restart Windows to finish.", 14, "Warn");
            rb.Margin = new Thickness(0, 0, 0, 12);
            panel.Children.Add(rb);
        }
        foreach (var o in outcomes)
        {
            var line = o.Message.Length > 0 ? $"{o.Kind}: {o.Message}" : o.Kind.ToString();
            var (icon, brush) = o.Kind switch
            {
                OutcomeKind.Applied or OutcomeKind.Reverted => ("circle-check", "Ok"),
                OutcomeKind.Already => ("circle-minus", "Mu"),
                OutcomeKind.Skipped => ("circle-slash", "Warn"),
                _ => ("circle-x", "Bad"),
            };
            panel.Children.Add(Row(o.Id, find(o.Id)?.Name ?? o.Id, line, icon, brush, find));
        }
        return panel;
    }

    /// <summary>A review / result row (New-AkariReviewRow, the design system's ReviewRow): the Tweak's Category blob,
    /// its name, the change or Outcome, a status icon on the right.</summary>
    public static Border Row(string id, string name, string line, string icon, string brush, Func<string, Tweak?> find)
    {
        var t = find(id);
        var blob = t is null ? "settings" : t.Section == "Apps" ? (t.Category == "Install" ? "download" : "trash-2") : Icons.Category(t.Category);
        var b = new Border { Tag = id, Margin = new Thickness(0, 0, 0, 8) };
        b.SetResourceReference(FrameworkElement.StyleProperty, "SettingCard");
        var dp = new DockPanel();
        var bl = Parts.Blob(blob, 32);
        bl.Margin = new Thickness(0, 0, 14, 0);
        DockPanel.SetDock(bl, Dock.Left);
        var st = Icons.Make(icon, 18, brush);
        st.VerticalAlignment = VerticalAlignment.Center;
        st.Margin = new Thickness(14, 0, 0, 0);
        DockPanel.SetDock(st, Dock.Right);
        var sp = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        var nm = Parts.Text(name, 14);
        nm.FontWeight = FontWeights.SemiBold;
        sp.Children.Add(nm);
        sp.Children.Add(Parts.Text(line, 13, brush == "Bad" ? "Bad" : "Mu"));
        dp.Children.Add(bl);
        dp.Children.Add(st);
        dp.Children.Add(sp);
        b.Child = dp;
        return b;
    }
}
