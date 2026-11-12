using System.Windows;
using System.Windows.Controls;
using System.Windows.Documents;
using AkariOS.App.Look;
using AkariOS.Core.Unattend;

namespace AkariOS.App.Pages;

/// <summary>
/// The Unattend Generator's form in WPF (src/UI/UnattendForm.ps1): one card per section of the model
/// (<see cref="UnattendForm"/>), each control bound both ways to its field. A radio option's or a checkbox's branch is
/// indented under it and shown while it is picked (the control's Tag); rows that grow show the used ones and one empty.
/// </summary>
public static class UnattendFormView
{
    public static void AddSections(Panel panel, UnattendForm form)
    {
        foreach (var section in form.Sections)
        {
            var (card, body) = Parts.Card(section.Title);
            Items(body, section.Items);
            panel.Children.Add(card);
        }
    }

    private static void Items(Panel p, IEnumerable<FormItem> items)
    {
        foreach (var item in items)
            switch (item)
            {
                case FormNote n:
                    var note = Parts.Text(n.Text);
                    note.FontWeight = FontWeights.SemiBold;
                    note.Margin = new Thickness(0, 10, 0, 4);
                    p.Children.Add(note);
                    break;
                case FormRadio r: Radio(p, r); break;
                case FormCheck c:
                    var box = Check(c.Binding, c.Label);
                    p.Children.Add(box);
                    if (c.Items.Count > 0) Branch(p, box, c.Binding, () => c.Binding.On, c.Items);
                    break;
                case FormInput i:
                    p.Children.Add(Label(i.Label));
                    p.Children.Add(Input(i.Binding, i.Kind));
                    break;
                case FormSelect s:
                    p.Children.Add(Label(s.Label));
                    p.Children.Add(Combo(s.Binding));
                    break;
                case FormChecks m: Checks(p, m); break;
                case FormAccounts a: Accounts(p, a.Rows); break;
                case FormBloatware b: Bloatware(p, b); break;
                case FormScripts s: Scripts(p, s); break;
                case FormComponents c: Components(p, c.Rows); break;
            }
    }

    private static TextBlock Label(string text)
    {
        var t = Parts.Text(text, 13, "Mu");
        t.Margin = new Thickness(0, 6, 0, 3);
        return t;
    }

    private static void Radio(Panel p, FormRadio r)
    {
        var buttons = new List<(RadioButton Button, string Value)>();
        foreach (var o in r.Options)
        {
            var rb = new RadioButton { Content = o.Label, GroupName = "ua-" + r.Binding.Field, Margin = new Thickness(0, 3, 0, 3) };
            rb.SetResourceReference(FrameworkElement.StyleProperty, "Radio");
            rb.Checked += (_, _) => r.Binding.Pick(o.Value);
            p.Children.Add(rb);
            buttons.Add((rb, o.Value));
            if (o.Items.Count > 0) Branch(p, rb, r.Binding, () => r.Binding.Value == o.Value, o.Items);
        }
        void Sync()
        {
            foreach (var (b, v) in buttons) b.IsChecked = r.Binding.Value == v;
        }
        r.Binding.Changed += Sync;
        Sync();
    }

    /// <summary>A branch: indented under its radio option or checkbox (its Tag), shown while picked.</summary>
    private static void Branch(Panel p, FrameworkElement gate, FormBinding binding, Func<bool> open, IReadOnlyList<FormItem> items)
    {
        var panel = new StackPanel { Margin = new Thickness(28, 2, 0, 6) };
        gate.Tag = panel;
        Items(panel, items);
        p.Children.Add(panel);
        void Sync() => panel.Visibility = open() ? Visibility.Visible : Visibility.Collapsed;
        binding.Changed += Sync;
        Sync();
    }

    private static CheckBox Check(FormBinding b, string label, double width = double.NaN)
    {
        var cb = new CheckBox { Content = label, Margin = new Thickness(0, 3, 8, 3), Width = width };
        cb.SetResourceReference(FrameworkElement.StyleProperty, "Check");
        cb.IsChecked = b.On;
        cb.Checked += (_, _) => b.SetOn(true);
        cb.Unchecked += (_, _) => b.SetOn(false);
        b.Changed += () => cb.IsChecked = b.On;
        return cb;
    }

    private static TextBox Input(FormBinding b, string kind, double height = 160)
    {
        var tb = new TextBox { Text = b.Value ?? "" };
        tb.SetResourceReference(FrameworkElement.StyleProperty, "Flat");
        if (kind == "Multi")
        {
            tb.AcceptsReturn = true;
            tb.AcceptsTab = true;
            tb.Height = height;
            tb.VerticalScrollBarVisibility = ScrollBarVisibility.Auto;
            tb.HorizontalScrollBarVisibility = ScrollBarVisibility.Auto;
            tb.SetResourceReference(TextElement.FontFamilyProperty, "FontMono");
        }
        else if (kind == "Number")
        {
            tb.Width = 140;
            tb.HorizontalAlignment = HorizontalAlignment.Left;
        }
        tb.TextChanged += (_, _) => b.Pick(tb.Text);
        b.Changed += () => { if (tb.Text != (b.Value ?? "")) tb.Text = b.Value ?? ""; };
        return tb;
    }

    private static ComboBox Combo(FormBinding b)
    {
        var cb = new ComboBox { ItemsSource = b.Choices, DisplayMemberPath = nameof(FormChoice.Name), SelectedValuePath = nameof(FormChoice.Id), IsTextSearchEnabled = true };
        cb.SetResourceReference(FrameworkElement.StyleProperty, "Combo");
        var count = b.Choices.Count;
        cb.SelectedValue = b.Value;
        cb.SelectionChanged += (_, _) => { if (cb.SelectedValue is string v) b.Pick(v); };
        b.Changed += () =>
        {
            // a value its list lacked was added first
            if (count != b.Choices.Count) { count = b.Choices.Count; cb.Items.Refresh(); }
            cb.SelectedValue = b.Value;
        };
        return cb;
    }

    private static void Checks(Panel p, FormChecks m)
    {
        p.Children.Add(Label(m.Label));
        var wrap = new WrapPanel();
        var boxes = new List<(CheckBox Box, string Id)>();
        foreach (var c in m.Binding.Choices)
        {
            var cb = new CheckBox { Content = c.Name, Margin = new Thickness(0, 3, 20, 3), IsChecked = m.Binding.Picked.Contains(c.Id) };
            cb.SetResourceReference(FrameworkElement.StyleProperty, "Check");
            void Picked() => m.Binding.SetPicked(boxes.Where(x => x.Box.IsChecked == true).Select(x => x.Id));
            cb.Checked += (_, _) => Picked();
            cb.Unchecked += (_, _) => Picked();
            wrap.Children.Add(cb);
            boxes.Add((cb, c.Id));
        }
        m.Binding.Changed += () => { foreach (var (box, id) in boxes) box.IsChecked = m.Binding.Picked.Contains(id); };
        p.Children.Add(wrap);
    }

    /// <summary>The rows' elements shown as the model says (the used ones and one empty), and an Add button.</summary>
    private static void Rows(Panel p, FormRows rows, IReadOnlyList<FrameworkElement> elements, string add)
    {
        foreach (var e in elements) p.Children.Add(e);
        void Sync()
        {
            for (var r = 0; r < elements.Count; r++) elements[r].Visibility = r < rows.Shown ? Visibility.Visible : Visibility.Collapsed;
        }
        rows.Changed += Sync;
        Sync();
        var b = Parts.Button(add, click: rows.Add);
        b.HorizontalAlignment = HorizontalAlignment.Left;
        b.Margin = new Thickness(0, 4, 0, 8);
        p.Children.Add(b);
    }

    private static Grid Columns(params GridLength[] widths)
    {
        var g = new Grid();
        foreach (var w in widths) g.ColumnDefinitions.Add(new ColumnDefinition { Width = w });
        return g;
    }

    private static GridLength Star(double n) => new(n, GridUnitType.Star);

    private static void Accounts(Panel p, FormRows rows)
    {
        var head = Columns(Star(3), Star(3), Star(3), Star(2));
        string[] titles = ["Account name", "Display name", "Password", "Group"];
        for (var i = 0; i < titles.Length; i++)
        {
            var l = Label(titles[i]);
            Grid.SetColumn(l, i);
            head.Children.Add(l);
        }
        p.Children.Add(head);
        var elements = rows.Rows.Select(row =>
        {
            var g = Columns(Star(3), Star(3), Star(3), Star(2));
            g.Margin = new Thickness(0, 0, 0, 4);
            for (var c = 0; c < 3; c++)
            {
                var tb = Input(row[c], "Text");
                tb.Margin = new Thickness(0, 0, 6, 0);
                Grid.SetColumn(tb, c);
                g.Children.Add(tb);
            }
            var group = Combo(row[3]);
            Grid.SetColumn(group, 3);
            g.Children.Add(group);
            return (FrameworkElement)g;
        }).ToList();
        Rows(p, rows, elements, "Add account");
    }

    private static void Bloatware(Panel p, FormBloatware b)
    {
        var bar = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 0, 0, 6) };
        bar.Children.Add(Parts.Button("Select all", click: () => { foreach (var (x, _) in b.Items) x.SetOn(true); }));
        bar.Children.Add(Parts.Button("Select none", click: () => { foreach (var (x, _) in b.Items) x.SetOn(false); }));
        p.Children.Add(bar);
        var wrap = new WrapPanel();
        foreach (var (binding, label) in b.Items) wrap.Children.Add(Check(binding, label, 250));
        p.Children.Add(wrap);
    }

    private static void Scripts(Panel p, FormScripts s)
    {
        p.Children.Add(Label(s.Label));
        var elements = s.Rows.Rows.Select(row =>
        {
            var g = Columns(new GridLength(90), Star(1));
            g.Margin = new Thickness(0, 0, 0, 6);
            var type = Combo(row[0]);
            type.VerticalAlignment = VerticalAlignment.Top;
            type.Margin = new Thickness(0, 0, 6, 0);
            var tb = Input(row[1], "Multi", 90);
            Grid.SetColumn(tb, 1);
            g.Children.Add(type);
            g.Children.Add(tb);
            return (FrameworkElement)g;
        }).ToList();
        Rows(p, s.Rows, elements, "Add script");
    }

    private static void Components(Panel p, FormRows rows)
    {
        var elements = rows.Rows.Select(row =>
        {
            var sp = new StackPanel { Margin = new Thickness(0, 0, 0, 10) };
            sp.Children.Add(Combo(row[0]));
            var tb = Input(row[1], "Multi", 90);
            tb.Margin = new Thickness(0, 4, 0, 0);
            sp.Children.Add(tb);
            return (FrameworkElement)sp;
        }).ToList();
        Rows(p, rows, elements, "Add component");
    }
}
