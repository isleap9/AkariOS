using System.Windows;
using System.Windows.Controls;
using AkariOS.App.Look;
using AkariOS.App.Shell;
using AkariOS.Core.Iso;
using AkariOS.Core.Machine;

namespace AkariOS.App.Pages;

/// <summary>
/// The ISO Builder (src/UI/IsoBuilder.ps1; its tab and Home tile, full page, Back leads Home): a custom Windows 11 ISO
/// after zoicware's zISO Tweaker, one long page in zISO's order: 1 the ISO (a file, UUP Dump, Massgrave), the work and
/// output folder, Open ISO; 2 the edition; 3 the answer file; 4-6 zISO's options by Group, 6 also the image's own
/// lists; 7 AkariOS; Build. Built once per run. Every slow step is a background job (IsoPage.Jobs.cs): one at a time,
/// refused while other changes run and refusing them (<see cref="Running"/>).
/// </summary>
public sealed partial class IsoPage(AppServices s)
{
    public const string Title = "ISO Builder";

    private static readonly (string Group, string Title)[] GroupTitles =
        [("Update", "4  Windows Update"), ("Security", "5  Security and privacy"), ("Apps", "6  Apps")];

    private static readonly (string Kind, string Title)[] ListTitles =
        [("Apps", "Store apps"), ("Capabilities", "Optional features"), ("Features", "Windows features"), ("Packages", "OS packages (advanced)")];

    private FrameworkElement? _view;
    private IReadOnlyList<IsoOption>? _options;

    // 1 the ISO
    private readonly RadioButton _srcFile = Radio("iso-src", "An ISO file I have");
    private readonly RadioButton _srcUup = Radio("iso-src", "Download with UUP Dump (23H2 to 26H2, any language, Home to IoT Enterprise)");
    private readonly RadioButton _srcMg = Radio("iso-src", "Download from Massgrave (LTSC, IoT LTSC, consumer and business media)");
    private readonly TextBox _isoPath = Box();
    private readonly ComboBox _uupVersion = Combo(110), _uupLang = Combo(200), _uupEdition = Combo(180);
    private readonly TextBlock _uupNote = Note("Pick a version. UUP Dump builds the ISO from Microsoft's own files: allow 20 to 60 minutes.");
    private readonly ComboBox _mgProduct = Combo(300), _mgFile = Combo(220);
    private const string MgHint = "Massgrave's links go to file hosts Akari can't download from: your browser does, then Akari finds the file in Downloads.";
    private readonly TextBlock _mgNote = Note(MgHint);
    private readonly TextBox _outDir = Box();
    private readonly TextBlock _openNote = Note("");

    // 2 the edition, 3 the answer file
    private readonly ComboBox _edition = Combo(320);
    private readonly RadioButton _ansNone = Radio("iso-ans", "None: setup asks everything as usual");
    private readonly RadioButton _ansLocal = Radio("iso-ans", "A local account (this PC's language, keyboard and time zone; setup still asks for the disk)");
    private readonly RadioButton _ansGen = Radio("iso-ans", "The Unattend Generator's choices");
    private readonly CheckBox _skipOobe = Check("Skip the setup questions (OOBE) and create this administrator", true);
    private readonly TextBox _user = Box(200), _password = Box(200);

    // 4-6 the options, 6 the image's lists
    private readonly Dictionary<string, CheckBox> _optionBoxes = new(StringComparer.OrdinalIgnoreCase);
    private readonly TextBlock _listNote = Note("Open the ISO first: the lists come from the edition itself (mounting it takes a few minutes).");
    private readonly Dictionary<string, (TextBlock Head, ScrollViewer View, StackPanel Items, string Title)> _lists = new(StringComparer.OrdinalIgnoreCase);

    // 7 AkariOS, Build
    private readonly CheckBox _akari = Check("Put AkariOS on the new Windows (C:\\AkariOS, a Start menu and a desktop shortcut; nothing runs by itself)", true);
    private readonly TextBlock _akariNote = Note("");
    private readonly TextBlock _error = Note("", "Bad");
    private readonly TextBlock _result = Note("", "Ok");
    private readonly Button _openOut = Parts.Button("Open folder");

    private IReadOnlyList<IsoOption> Options => _options ??= IsoData.Options(s.Engine.Files);

    // ---- what the page shows (tests read and set these as the user would)

    public string IsoPath { get => _isoPath.Text; set => _isoPath.Text = value; }
    public string OutDir { get => _outDir.Text; set => _outDir.Text = value; }
    public string OpenNote => _openNote.Text;
    public IReadOnlyList<string> EditionNames => Labels(_edition);
    public bool EditionEnabled => _edition.IsEnabled;
    public int EditionIndex { get => _edition.SelectedIndex; set => _edition.SelectedIndex = value; }

    /// <summary>The ISO's source: File, Uup or Massgrave.</summary>
    public string Source
    {
        get => _srcUup.IsChecked == true ? "Uup" : _srcMg.IsChecked == true ? "Massgrave" : "File";
        set => (value switch { "Uup" => _srcUup, "Massgrave" => _srcMg, _ => _srcFile }).IsChecked = true;
    }

    public string UupNote => _uupNote.Text;
    public IReadOnlyList<string> UupVersions => Labels(_uupVersion);
    public int UupVersionIndex { get => _uupVersion.SelectedIndex; set => _uupVersion.SelectedIndex = value; }
    public IReadOnlyList<string> UupLanguages => Labels(_uupLang);
    public string UupLanguage => (_uupLang.SelectedItem as ComboBoxItem)?.Content as string ?? "";
    public int UupLanguageIndex { get => _uupLang.SelectedIndex; set => _uupLang.SelectedIndex = value; }
    public IReadOnlyList<string> UupEditionNames => Labels(_uupEdition);
    public string UupEdition => (_uupEdition.SelectedItem as ComboBoxItem)?.Content as string ?? "";

    public string MassgraveNote => _mgNote.Text;
    public IReadOnlyList<string> MassgraveProducts => Labels(_mgProduct);
    public int MassgraveProductIndex { get => _mgProduct.SelectedIndex; set => _mgProduct.SelectedIndex = value; }
    public IReadOnlyList<string> MassgraveFiles => Labels(_mgFile);

    /// <summary>The answer file: None, Local or Generator.</summary>
    public string Answer
    {
        get => _ansNone.IsChecked == true ? "None" : _ansGen.IsChecked == true ? "Generator" : "Local";
        set => (value switch { "None" => _ansNone, "Generator" => _ansGen, _ => _ansLocal }).IsChecked = true;
    }

    public bool SkipOobe { get => _skipOobe.IsChecked == true; set => _skipOobe.IsChecked = value; }
    public string User { get => _user.Text; set => _user.Text = value; }
    public string Password { get => _password.Text; set => _password.Text = value; }

    /// <summary>An option's box: ticked, and whether another picked one rules it out (greyed).</summary>
    public bool Option(string id) => _optionBoxes[id].IsChecked == true;
    public bool OptionEnabled(string id) => _optionBoxes[id].IsEnabled;

    /// <summary>Ticks an option as a click would.</summary>
    public void SetOption(string id, bool on)
    {
        _optionBoxes[id].IsChecked = on;
        UpdateOptions();
    }

    public string ListNote => _listNote.Text;

    /// <summary>A list's heading ("" while hidden) and its rows (label, ticked).</summary>
    public string ListHeading(string kind) => _lists[kind].Head.Visibility == Visibility.Visible ? _lists[kind].Head.Text : "";
    public IReadOnlyList<(string Label, bool Ticked)> ListItems(string kind) =>
        [.. _lists[kind].Items.Children.OfType<CheckBox>().Select(c => ((string)c.Content, c.IsChecked == true))];
    public void Tick(string kind, string label, bool on = true) =>
        _lists[kind].Items.Children.OfType<CheckBox>().Single(c => (string)c.Content == label).IsChecked = on;

    public bool AkariOS { get => _akari.IsChecked == true; set => _akari.IsChecked = value; }
    public bool AkariOSEnabled => _akari.IsEnabled;
    public string AkariOSNote => _akariNote.Text;

    public string BuildError => _error.Text;
    public string BuildResult => _result.Text;
    public bool OpenFolderShown => _openOut.Visibility == Visibility.Visible;

    private static IReadOnlyList<string> Labels(ComboBox c) => [.. c.Items.Cast<ComboBoxItem>().Select(i => (string)i.Content)];

    public UIElement Build()
    {
        if (_view != null) return _view;
        var stack = new StackPanel();
        stack.Children.Add(IsoCard());
        stack.Children.Add(EditionCard());
        stack.Children.Add(AnswerCard());
        foreach (var (group, title) in GroupTitles) stack.Children.Add(OptionsCard(group, title));
        stack.Children.Add(AkariCard());
        stack.Children.Add(BuildCard());
        var back = Parts.Button("Back", click: () => s.Shell.Open("Home"));
        back.HorizontalAlignment = HorizontalAlignment.Left;
        back.MinWidth = 96;
        stack.Children.Add(back);

        // one readable column on the left, at most 860 px wide
        var column = new Grid();
        column.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star), MaxWidth = 860 });
        column.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(0, GridUnitType.Auto) });
        column.Children.Add(stack);
        return _view = column;
    }

    // ---- the cards

    private Border IsoCard()
    {
        var (card, body) = Card("1  Windows 11 ISO", "An ISO you have, or one downloaded here. Akari copies it to a work folder, so the ISO itself is not changed.");
        _srcFile.IsChecked = true;
        body.Children.Add(_srcFile);
        Branch(body, _srcFile, Row(_isoPath, Parts.Button("Browse…", click: PickIso)));

        body.Children.Add(_srcUup);
        foreach (var (version, _) in Uup.Versions) _uupVersion.Items.Add(new ComboBoxItem { Content = $"Windows 11 {version}", Tag = version });
        _uupVersion.SelectionChanged += (_, _) => UupVersionPicked();
        _uupLang.SelectionChanged += (_, _) => { if (!_filling) UupEditions(); };
        Branch(body, _srcUup, Row(_uupVersion, _uupLang, _uupEdition), Row(Parts.Button("Download", click: UupDownload)), _uupNote);

        body.Children.Add(_srcMg);
        _srcMg.Checked += (_, _) => { if (_massgrave.Count == 0) MassgraveList(); };
        _mgProduct.SelectionChanged += (_, _) => MassgraveLanguages();
        Branch(body, _srcMg, Row(_mgProduct, _mgFile), Row(Parts.Button("Open download page", click: OpenMassgravePage)), _mgNote);

        body.Children.Add(Label("Work and output folder (NTFS, 25 GB free; the ISO is saved here)"));
        try { _outDir.Text = UserFolders.Get(s.Engine.Registry, "Downloads") ?? ""; }
        catch (Exception e) when (e is System.IO.IOException or UnauthorizedAccessException or System.Security.SecurityException or InvalidOperationException) { _outDir.Text = ""; }
        body.Children.Add(Row(_outDir, Parts.Button("Browse…", click: PickFolder)));
        body.Children.Add(Row(Parts.Button("Open ISO", "Accent", OpenIso)));
        body.Children.Add(_openNote);
        return card;
    }

    private Border EditionCard()
    {
        var (card, body) = Card("2  Edition", "The ISO keeps only this edition.");
        _edition.IsEnabled = false;
        body.Children.Add(_edition);
        return card;
    }

    private Border AnswerCard()
    {
        var (card, body) = Card("3  Answer file", "autounattend.xml at the root of the ISO: Windows setup reads it by itself.");
        _ansLocal.IsChecked = true;
        body.Children.Add(_ansNone);
        body.Children.Add(_ansLocal);
        _user.Text = "Admin";
        var account = Branch(null, _skipOobe,
            Row(Label("User name "), _user, Label("Password "), _password),
            Note("The password is in the answer file (Base64, not encrypted): anyone with the ISO can read it. Leave it empty for none."));
        Branch(body, _ansLocal, _skipOobe, account);
        body.Children.Add(_ansGen);
        Branch(body, _ansGen, Row(Parts.Button("Open the Unattend Generator", click: () => s.Shell.Open("Unattend Generator"))));
        return card;
    }

    private Border OptionsCard(string group, string title)
    {
        var (card, body) = Card(title, "");
        foreach (var o in Options.Where(o => o.Group == group))
        {
            var cb = Check(o.Name, false);
            cb.Tag = o.Id;
            cb.ToolTip = o.Description;
            cb.Click += (_, _) => UpdateOptions();
            body.Children.Add(cb);
            var d = Parts.Text(o.Description, 12, "Mu");
            d.Margin = new Thickness(30, 0, 0, 6);
            body.Children.Add(d);
            _optionBoxes[o.Id] = cb;
        }
        if (group != "Apps") return card;
        body.Children.Add(Label("Apps and features in the image"));
        body.Children.Add(Row(Parts.Button("Read the image's apps", click: ReadImage), Parts.Button("Select recommended", click: SelectRecommended),
            Parts.Button("Clear", click: ClearLists)));
        body.Children.Add(_listNote);
        foreach (var (kind, listTitle) in ListTitles)
        {
            var head = Parts.Text(listTitle, 13);
            head.FontWeight = FontWeights.SemiBold;
            head.Margin = new Thickness(0, 10, 0, 4);
            var items = new StackPanel();
            var view = new ScrollViewer { MaxHeight = 240, VerticalScrollBarVisibility = ScrollBarVisibility.Auto, Content = items };
            head.Visibility = view.Visibility = Visibility.Collapsed;
            body.Children.Add(head);
            body.Children.Add(view);
            _lists[kind] = (head, view, items, listTitle);
        }
        return card;
    }

    private Border AkariCard()
    {
        var (card, body) = Card("7  AkariOS", "");
        body.Children.Add(_akari);
        body.Children.Add(_akariNote);
        if (s.AkariExe is null)
        {
            _akari.IsChecked = false;
            _akari.IsEnabled = false;
            _akariNote.Text = "Not in a developer build: only the published AkariOS-Native.exe can be copied into the image.";
        }
        return card;
    }

    private Border BuildCard()
    {
        var (card, body) = Card("Build", "Allow 20 to 40 minutes. Akari can't be used meanwhile; the status bar shows each step.");
        _openOut.Visibility = Visibility.Collapsed;
        _openOut.Click += (_, _) => s.Open.Folder(_outDir.Text.Trim());
        body.Children.Add(Row(Parts.Button("Build ISO", "Accent", BuildIso), _openOut));
        body.Children.Add(_error);
        body.Children.Add(_result);
        return card;
    }

    /// <summary>Options that rule each other out: the other one unticked and greyed (Update-AkariIsoOptions).</summary>
    private void UpdateOptions()
    {
        var blocked = IsoData.Blocked(PickedOptions(), Options);
        foreach (var (id, cb) in _optionBoxes)
        {
            var off = blocked.Contains(id, StringComparer.OrdinalIgnoreCase);
            if (off) cb.IsChecked = false;
            cb.IsEnabled = !off;
        }
    }

    private string[] PickedOptions() => [.. _optionBoxes.Where(p => p.Value.IsChecked == true).Select(p => p.Key)];

    // ---- building blocks

    private static (Border Card, StackPanel Body) Card(string title, string sub)
    {
        var (card, body) = Parts.Card(title);
        if (sub.Length > 0)
        {
            var t = Parts.Text(sub, 13, "Mu");
            t.Margin = new Thickness(0, -4, 0, 8);
            body.Children.Add(t);
        }
        return (card, body);
    }

    private static RadioButton Radio(string group, string text)
    {
        var r = new RadioButton { GroupName = group, Content = text, Margin = new Thickness(0, 3, 0, 3) };
        r.SetResourceReference(FrameworkElement.StyleProperty, "Radio");
        return r;
    }

    private static CheckBox Check(string text, bool on)
    {
        var c = new CheckBox { Content = text, IsChecked = on, Margin = new Thickness(0, 3, 0, 3) };
        c.SetResourceReference(FrameworkElement.StyleProperty, "Check");
        return c;
    }

    private static ComboBox Combo(double width)
    {
        var c = new ComboBox { MinWidth = width, Margin = new Thickness(0, 0, 8, 0) };
        c.SetResourceReference(FrameworkElement.StyleProperty, "Combo");
        return c;
    }

    private static TextBox Box(double width = 420)
    {
        var t = new TextBox { Width = width, Margin = new Thickness(0, 0, 8, 0) };
        t.SetResourceReference(FrameworkElement.StyleProperty, "Flat");
        return t;
    }

    private static TextBlock Note(string text, string brush = "Mu")
    {
        var t = Parts.Text(text, 13, brush);
        t.Margin = new Thickness(0, 4, 0, 0);
        return t;
    }

    private static TextBlock Label(string text)
    {
        var t = Parts.Text(text, 13, "Mu");
        t.Margin = new Thickness(0, 6, 8, 3);
        t.VerticalAlignment = VerticalAlignment.Center;
        return t;
    }

    private static StackPanel Row(params UIElement[] items)
    {
        var r = new StackPanel { Orientation = Orientation.Horizontal, Margin = new Thickness(0, 6, 0, 6) };
        foreach (var i in items) r.Children.Add(i);
        return r;
    }

    /// <summary>A panel shown while its gate (a radio or check box) is on, indented under it (New-AkariIsoBranch);
    /// added to <paramref name="parent"/> when one is given.</summary>
    private static StackPanel Branch(Panel? parent, ToggleButtonGate gate, params UIElement[] items)
    {
        var p = new StackPanel { Margin = new Thickness(28, 2, 0, 6) };
        foreach (var i in items) p.Children.Add(i);
        var g = gate.Button;
        g.Tag = p;
        void Sync() => p.Visibility = g.IsChecked == true ? Visibility.Visible : Visibility.Collapsed;
        g.Checked += (_, _) => Sync();
        g.Unchecked += (_, _) => Sync();
        Sync();
        parent?.Children.Add(p);
        return p;
    }

    /// <summary>A radio or check box as a branch's gate.</summary>
    private readonly record struct ToggleButtonGate(System.Windows.Controls.Primitives.ToggleButton Button)
    {
        public static implicit operator ToggleButtonGate(RadioButton r) => new(r);
        public static implicit operator ToggleButtonGate(CheckBox c) => new(c);
    }

    private static void Fill<T>(ComboBox combo, IEnumerable<T> items, Func<T, string> label)
    {
        combo.Items.Clear();
        foreach (var i in items) combo.Items.Add(new ComboBoxItem { Content = label(i), Tag = i });
        if (combo.Items.Count > 0) combo.SelectedIndex = 0;
    }

    private static T? Picked<T>(ComboBox combo) where T : class => (combo.SelectedItem as ComboBoxItem)?.Tag as T;
}
