using System.ComponentModel;
using AkariOS.App.ViewModels;
using AkariOS.Core.Unattend;
using Microsoft.UI.Text;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;

namespace AkariOS.App.Views;

/// <summary>
/// His form in WinUI (src/UI/UnattendForm.ps1; the WPF app's UnattendFormView): an Expander per section (the first
/// open; its header says "Default" or "Changed from the default"), each control bound both ways to its field of Core's
/// <see cref="UnattendForm"/>. A radio option's or checkbox's branch is indented under it and shown while picked; rows
/// that grow show the used ones and one empty. A section's controls are made the first time it opens. Glue only: the
/// values live in the form, the page detaches every handler when it unloads.
/// </summary>
public sealed class UnattendFormView
{
    private const double FieldWidth = 360;
    private readonly List<Action> _detach = [];

    /// <summary>The handlers this view added to the form, removed (the page left).</summary>
    public void Detach()
    {
        foreach (var d in _detach) d();
        _detach.Clear();
    }

    private void Watch(FormBinding b, Action sync)
    {
        b.Changed += sync;
        _detach.Add(() => b.Changed -= sync);
    }

    private void Watch(FormRows rows, Action sync)
    {
        rows.Changed += sync;
        _detach.Add(() => rows.Changed -= sync);
    }

    public void AddSections(Panel panel, IReadOnlyList<UaSectionViewModel> sections)
    {
        for (var i = 0; i < sections.Count; i++)
        {
            var s = sections[i];
            var ex = new Expander
            {
                HorizontalAlignment = HorizontalAlignment.Stretch,
                HorizontalContentAlignment = HorizontalAlignment.Stretch,
                Header = Header(s),
            };
            var built = false;
            void Build()
            {
                if (built) return;
                built = true;
                var body = new StackPanel { Padding = new Thickness(36, 4, 8, 8) };
                Items(body, s.Section.Items);
                ex.Content = body;
            }
            ex.Expanding += (_, _) => Build();
            if (i == 0)
            {
                Build();
                ex.IsExpanded = true;
            }
            panel.Children.Add(ex);
        }
    }

    private Grid Header(UaSectionViewModel s)
    {
        var g = new Grid { ColumnSpacing = 16, Padding = new Thickness(0, 12, 0, 12) };
        g.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });
        g.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        g.Children.Add(new FontIcon { Glyph = s.Glyph, FontSize = 16, VerticalAlignment = VerticalAlignment.Center });
        var text = new StackPanel { VerticalAlignment = VerticalAlignment.Center };
        text.Children.Add(new TextBlock { Text = s.Title });
        var status = Caption(s.Status);
        text.Children.Add(status);
        Grid.SetColumn(text, 1);
        g.Children.Add(text);
        PropertyChangedEventHandler h = (_, e) =>
        {
            if (e.PropertyName == nameof(UaSectionViewModel.Status)) status.Text = s.Status;
        };
        s.PropertyChanged += h;
        _detach.Add(() => s.PropertyChanged -= h);
        return g;
    }

    private static TextBlock Caption(string text) => new()
    {
        Text = text,
        Style = (Style)Application.Current.Resources["CaptionTextBlockStyle"],
        Foreground = (Brush)Application.Current.Resources["TextFillColorSecondaryBrush"],
        TextWrapping = TextWrapping.Wrap,
    };

    private void Items(Panel p, IEnumerable<FormItem> items)
    {
        foreach (var item in items)
            switch (item)
            {
                case FormNote n:
                    p.Children.Add(new TextBlock { Text = n.Text, FontWeight = FontWeights.SemiBold, TextWrapping = TextWrapping.Wrap, Margin = new Thickness(0, 12, 0, 4) });
                    break;
                case FormRadio r: Radio(p, r); break;
                case FormCheck c:
                    p.Children.Add(Check(c.Binding, c.Label));
                    if (c.Items.Count > 0) Branch(p, c.Binding, () => c.Binding.On, c.Items);
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
        var t = Caption(text);
        t.Margin = new Thickness(0, 8, 0, 4);
        return t;
    }

    private void Radio(Panel p, FormRadio r)
    {
        var buttons = new List<(RadioButton Button, string Value)>();
        foreach (var o in r.Options)
        {
            var rb = new RadioButton { Content = o.Label, GroupName = "ua-" + r.Binding.Field, Margin = new Thickness(0, 2, 0, 2) };
            rb.Checked += (_, _) => r.Binding.Pick(o.Value);
            p.Children.Add(rb);
            buttons.Add((rb, o.Value));
            if (o.Items.Count > 0) Branch(p, r.Binding, () => r.Binding.Value == o.Value, o.Items);
        }
        void Sync()
        {
            foreach (var (b, v) in buttons) b.IsChecked = r.Binding.Value == v;
        }
        Watch(r.Binding, Sync);
        Sync();
    }

    /// <summary>A branch: indented under its radio option or checkbox, shown while picked.</summary>
    private void Branch(Panel p, FormBinding binding, Func<bool> open, IReadOnlyList<FormItem> items)
    {
        var panel = new StackPanel { Margin = new Thickness(28, 0, 0, 8) };
        Items(panel, items);
        p.Children.Add(panel);
        void Sync() => panel.Visibility = open() ? Visibility.Visible : Visibility.Collapsed;
        Watch(binding, Sync);
        Sync();
    }

    private CheckBox Check(FormBinding b, string label)
    {
        var cb = new CheckBox { Content = label, IsChecked = b.On };
        cb.Checked += (_, _) => b.SetOn(true);
        cb.Unchecked += (_, _) => b.SetOn(false);
        Watch(b, () => cb.IsChecked = b.On);
        return cb;
    }

    private TextBox Input(FormBinding b, string kind, double height = 160)
    {
        var tb = new TextBox { Text = b.Value ?? "", HorizontalAlignment = HorizontalAlignment.Left, Width = FieldWidth };
        if (kind == "Multi")
        {
            tb.AcceptsReturn = true;
            tb.TextWrapping = TextWrapping.NoWrap;
            tb.Height = height;
            tb.Width = double.NaN;
            tb.HorizontalAlignment = HorizontalAlignment.Stretch;
            tb.FontFamily = new FontFamily("Cascadia Mono, Consolas");
            tb.IsSpellCheckEnabled = false;
            ScrollViewer.SetHorizontalScrollBarVisibility(tb, ScrollBarVisibility.Auto);
            ScrollViewer.SetVerticalScrollBarVisibility(tb, ScrollBarVisibility.Auto);
        }
        else if (kind == "Number") tb.Width = 140;
        tb.TextChanged += (_, _) => b.Pick(tb.Text);
        Watch(b, () => { if (tb.Text != (b.Value ?? "")) tb.Text = b.Value ?? ""; });
        return tb;
    }

    private ComboBox Combo(FormBinding b, double width = FieldWidth)
    {
        var cb = new ComboBox { HorizontalAlignment = HorizontalAlignment.Left, Width = width };
        var count = -1;
        var syncing = false;
        void Sync()
        {
            syncing = true;
            try
            {
                // a value its list lacked was added first (a keyboard of this PC)
                if (count != b.Choices.Count)
                {
                    count = b.Choices.Count;
                    cb.ItemsSource = b.Choices.Select(c => c.Name).ToList();
                }
                cb.SelectedIndex = b.Choices.FindIndex(c => c.Id == b.Value);
            }
            finally { syncing = false; }
        }
        cb.SelectionChanged += (_, _) =>
        {
            if (!syncing && cb.SelectedIndex >= 0 && cb.SelectedIndex < b.Choices.Count) b.Pick(b.Choices[cb.SelectedIndex].Id);
        };
        Watch(b, Sync);
        Sync();
        return cb;
    }

    /// <summary>Elements laid out in columns at least <paramref name="width"/> wide (WinUI has no WrapPanel).</summary>
    private static ItemsRepeater Wrap(IEnumerable<UIElement> elements, double width) => new()
    {
        ItemsSource = elements.ToList(),
        Layout = new UniformGridLayout { MinItemWidth = width, MinColumnSpacing = 8, ItemsStretch = UniformGridLayoutItemsStretch.Fill },
    };

    private void Checks(Panel p, FormChecks m)
    {
        p.Children.Add(Label(m.Label));
        var boxes = new List<(CheckBox Box, string Id)>();
        var syncing = false;
        foreach (var c in m.Binding.Choices)
        {
            var cb = new CheckBox { Content = c.Name, IsChecked = m.Binding.Picked.Contains(c.Id) };
            void Picked()
            {
                if (!syncing) m.Binding.SetPicked(boxes.Where(x => x.Box.IsChecked == true).Select(x => x.Id));
            }
            cb.Checked += (_, _) => Picked();
            cb.Unchecked += (_, _) => Picked();
            boxes.Add((cb, c.Id));
        }
        Watch(m.Binding, () =>
        {
            syncing = true;
            try { foreach (var (box, id) in boxes) box.IsChecked = m.Binding.Picked.Contains(id); }
            finally { syncing = false; }
        });
        p.Children.Add(Wrap(boxes.Select(b => (UIElement)b.Box), 220));
    }

    /// <summary>The rows' elements shown as the model says (the used ones and one empty), and an Add button.</summary>
    private void Rows(Panel p, FormRows rows, IReadOnlyList<FrameworkElement> elements, string add)
    {
        foreach (var e in elements) p.Children.Add(e);
        void Sync()
        {
            for (var r = 0; r < elements.Count; r++) elements[r].Visibility = r < rows.Shown ? Visibility.Visible : Visibility.Collapsed;
        }
        Watch(rows, Sync);
        Sync();
        var b = new Button { Content = add, Margin = new Thickness(0, 4, 0, 8) };
        b.Click += (_, _) => rows.Add();
        p.Children.Add(b);
    }

    private static Grid Columns(params GridLength[] widths)
    {
        var g = new Grid { ColumnSpacing = 6 };
        foreach (var w in widths) g.ColumnDefinitions.Add(new ColumnDefinition { Width = w });
        return g;
    }

    private static GridLength Star(double n) => new(n, GridUnitType.Star);

    private void Accounts(Panel p, FormRows rows)
    {
        GridLength[] widths = [Star(3), Star(3), Star(3), Star(2)];
        var head = Columns(widths);
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
            var g = Columns(widths);
            g.Margin = new Thickness(0, 0, 0, 4);
            for (var c = 0; c < 3; c++)
            {
                var tb = Input(row[c], "Text");
                (tb.Width, tb.HorizontalAlignment) = (double.NaN, HorizontalAlignment.Stretch);
                Grid.SetColumn(tb, c);
                g.Children.Add(tb);
            }
            var group = Combo(row[3], double.NaN);
            group.HorizontalAlignment = HorizontalAlignment.Stretch;
            Grid.SetColumn(group, 3);
            g.Children.Add(group);
            return (FrameworkElement)g;
        }).ToList();
        Rows(p, rows, elements, "Add account");
    }

    private void Bloatware(Panel p, FormBloatware b)
    {
        var bar = new StackPanel { Orientation = Orientation.Horizontal, Spacing = 8, Margin = new Thickness(0, 0, 0, 6) };
        var all = new Button { Content = "Select all" };
        all.Click += (_, _) => { foreach (var (x, _) in b.Items) x.SetOn(true); };
        var none = new Button { Content = "Select none" };
        none.Click += (_, _) => { foreach (var (x, _) in b.Items) x.SetOn(false); };
        bar.Children.Add(all);
        bar.Children.Add(none);
        p.Children.Add(bar);
        p.Children.Add(Wrap(b.Items.Select(x => (UIElement)Check(x.Binding, x.Label)), 240));
    }

    private void Scripts(Panel p, FormScripts s)
    {
        p.Children.Add(Label(s.Label));
        var elements = s.Rows.Rows.Select(row =>
        {
            var g = Columns(new GridLength(96), Star(1));
            g.Margin = new Thickness(0, 0, 0, 6);
            var type = Combo(row[0], 96);
            type.VerticalAlignment = VerticalAlignment.Top;
            var tb = Input(row[1], "Multi", 96);
            Grid.SetColumn(tb, 1);
            g.Children.Add(type);
            g.Children.Add(tb);
            return (FrameworkElement)g;
        }).ToList();
        Rows(p, s.Rows, elements, "Add script");
    }

    private void Components(Panel p, FormRows rows)
    {
        var elements = rows.Rows.Select(row =>
        {
            var sp = new StackPanel { Spacing = 4, Margin = new Thickness(0, 0, 0, 10) };
            sp.Children.Add(Combo(row[0]));
            sp.Children.Add(Input(row[1], "Multi", 96));
            return (FrameworkElement)sp;
        }).ToList();
        Rows(p, rows, elements, "Add component");
    }
}
