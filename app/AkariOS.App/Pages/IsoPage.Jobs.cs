using System.IO;
using System.Windows;
using System.Windows.Controls;
using AkariOS.Core.Apps;
using AkariOS.Core.Iso;
using AkariOS.Core.Runs;
using AkariOS.Core.Unattend;

namespace AkariOS.App.Pages;

/// <summary>The ISO Builder's actions and background jobs (src/UI/IsoBuilder.ps1's Start-AkariIso* and
/// Complete-AkariIsoJob): one job at a time; the long ones (Open, Read, Build, the UUP download) lock the page.</summary>
public sealed partial class IsoPage
{
    private static readonly string[] LongJobs = ["IsoOpen", "IsoRead", "IsoBuild", "IsoUup"];

    private bool _filling;
    private IReadOnlyList<MassgraveIso> _massgrave = [];
    private string _image = "";
    private IReadOnlyList<ImageApp>? _imageApps;
    private UupBuild? _uupBuild;
    private string _waiting = "";
    private IDisposable? _watch;
    private string _label = "";

    /// <summary>The running job's kind (IsoOpen, IsoRead, IsoBuild, IsoUup, IsoUupList, IsoMassgrave), else null.</summary>
    public string? Job { get; private set; }

    /// <summary>An ISO job runs: other changes are refused meanwhile, the update check is Blocked.</summary>
    public bool Running => Job is not null;

    /// <summary>One of the long jobs runs (Open, Read, Build, the UUP download): closing asks first.</summary>
    public bool Working => Job is not null && LongJobs.Contains(Job);

    /// <summary>Starts a job unless something else runs (Start-AkariIsoJob): the label in the log and status bar,
    /// the work in the background, then <paramref name="done"/> on the UI thread with the job cleared.</summary>
    private bool Start(string kind, string label, Func<object?> work, Action<object?> done)
    {
        if (Running) return false;
        if (s.Shell.Busy || s.Catalogue?.Running == true || s.Install?.Running == true)
        {
            s.Dialogs?.Message("Wait until the changes running now are done, then try again.", "Info", Title);
            return false;
        }
        Job = kind;
        _label = label;
        s.Shell.SetBusy(true, label, LongJobs.Contains(kind));
        s.Log.Write(label);
        s.Background(work, r =>
        {
            Job = null;
            s.Shell.SetBusy(false);
            done(r);
        });
        return true;
    }

    /// <summary>Closing while a long job runs stops it: asked first (the next launch discards a half-built image).</summary>
    public bool CanClose() => !Working || s.Dialogs?.Confirm(
        $"The ISO Builder is still working ({_label}). Closing stops it; a half-built image is discarded the next time AkariOS starts.\n\nClose anyway?",
        "Close", "Keep working", "Warning", Title) == true;

    private void PickIso() { if (s.Picker?.OpenIso() is { } f) _isoPath.Text = f; }

    private void PickFolder() { if (s.Picker?.Folder("Where should the ISO Builder work and save the ISO? (NTFS, 25 GB free)") is { } f) _outDir.Text = f; }

    private static string Error(Exception e) => e.Message;

    // ---- 1 the ISO

    /// <summary>Open ISO (Start-AkariIsoOpen): copied to the work folder, its editions read.</summary>
    public void OpenIso()
    {
        _error.Text = "";
        var iso = _isoPath.Text.Trim();
        var outDir = _outDir.Text.Trim();
        if (iso.Length == 0 || !File.Exists(iso)) { _openNote.Text = "Pick an ISO file first (or download one above)."; return; }
        if (outDir.Length == 0) { _openNote.Text = "Pick a work and output folder."; return; }
        if (s.IsoBuild is not { } build) { _openNote.Text = "Not opened: the ISO Builder isn't available here."; return; }
        Start("IsoOpen", "Copying the ISO and reading its editions", () =>
        {
            try { return build.Open(iso, outDir); }
            catch (Exception e) { return Error(e); }
        }, r =>
        {
            if (r is not IsoSource src) { _openNote.Text = $"Not opened: {r as string ?? "see the log"}"; return; }
            _image = src.Image;
            ResetLists();
            var supported = src.Editions.Where(e => e.Supported).ToList();
            Fill(_edition, supported, e => $"{e.Name} ({e.Version})");
            _edition.IsEnabled = true;
            _openNote.Text = $"Opened: {supported.Count} Windows 11 editions.";
        });
    }

    /// <summary>A downloaded ISO becomes the source: "An ISO file I have", ready to open (Set-AkariIsoSource).</summary>
    private void SetSource(string path, string note)
    {
        _isoPath.Text = path;
        _srcFile.IsChecked = true;
        _openNote.Text = $"{note}. Press Open ISO.";
        s.Log.Write($"ISO Builder: {note}");
    }

    // ---- UUP Dump

    /// <summary>A version picked: its newest build and languages (en-us picked), then its editions.</summary>
    private void UupVersionPicked()
    {
        if (Picked<string>(_uupVersion) is not { } v || s.IsoDownload is not { } dl) return;
        _filling = true;
        _uupLang.Items.Clear();
        _uupEdition.Items.Clear();
        _filling = false;
        Start("IsoUupList", $"Asking UUP Dump for Windows 11 {v}", () =>
        {
            var b = dl.Build(v);
            return (b, b.Ok ? dl.Languages(b.Value!.Id) : null);
        }, r =>
        {
            if (r is not ValueTuple<UupAnswer<UupBuild>, UupAnswer<IReadOnlyList<UupLanguage>>?> (var b, var langs)) { _uupNote.Text = "UUP Dump could not be asked: see the log."; return; }
            if (!b.Ok) { _uupNote.Text = b.Message; return; }
            _uupBuild = b.Value;
            if (langs is not { Ok: true }) { _uupNote.Text = langs?.Message ?? ""; return; }
            _uupNote.Text = $"{b.Value!.Title}. Pick a language and an edition.";
            _filling = true;
            Fill(_uupLang, langs.Value!, l => l.Name);
            if (_uupLang.Items.Cast<ComboBoxItem>().FirstOrDefault(i => ((UupLanguage)i.Tag).Code == "en-us") is { } en) _uupLang.SelectedItem = en;
            _filling = false;
            UupEditions();
        });
    }

    /// <summary>A language picked: its editions (Pro picked).</summary>
    private void UupEditions()
    {
        if (Picked<UupLanguage>(_uupLang) is not { } lang || _uupBuild is not { } build || s.IsoDownload is not { } dl) return;
        Start("IsoUupList", "Asking UUP Dump for its editions", () => dl.Editions(build.Id, lang.Code), r =>
        {
            if (r is not UupAnswer<IReadOnlyList<UupTarget>> e) { _uupNote.Text = "UUP Dump could not be asked: see the log."; return; }
            if (!e.Ok) { _uupNote.Text = e.Message; return; }
            Fill(_uupEdition, e.Value!, t => t.Label);
            if (_uupEdition.Items.Cast<ComboBoxItem>().FirstOrDefault(i => ((UupTarget)i.Tag).Label == "Pro") is { } pro) _uupEdition.SelectedItem = pro;
        });
    }

    /// <summary>Download (Start-AkariUupDownload): asked first, then UUP Dump's converter builds the ISO; it becomes the
    /// source.</summary>
    private void UupDownload()
    {
        var (v, lang, t) = (Picked<string>(_uupVersion), Picked<UupLanguage>(_uupLang), Picked<UupTarget>(_uupEdition));
        if (v is null || lang is null || t is null || _uupBuild is not { } build) { _uupNote.Text = "Pick a version, a language and an edition first."; return; }
        var outDir = _outDir.Text.Trim();
        if (outDir.Length == 0) { _uupNote.Text = "Pick a work and output folder below first."; return; }
        if (s.IsoDownload is not { } dl) return;
        var q = $"Download Windows 11 {v} {t.Label} ({lang.Name}) with UUP Dump?\n\nIt downloads several GB from Microsoft and builds the ISO: allow 20 to 60 minutes. AkariOS can't be used meanwhile.";
        if (s.Dialogs?.Confirm(q, "Download", "Cancel", "Question", Title) != true) return;
        Start("IsoUup", $"Downloading Windows 11 {v} {t.Label}", () => dl.SaveUup(v, build, lang.Code, t, outDir), r =>
        {
            if (r is IsoResult { Ok: true, Path: { } path }) SetSource(path, $"Downloaded: {path}");
            else _uupNote.Text = $"Not downloaded: {(r as IsoResult)?.Message ?? "see the log"}";
        });
    }

    // ---- Massgrave

    private void MassgraveList()
    {
        if (s.IsoDownload is not { } dl) return;
        _mgNote.Text = "Reading Massgrave's list…";
        Start("IsoMassgrave", "Reading Massgrave's list", () => dl.Catalogue(), r =>
        {
            if (r is not UupAnswer<IReadOnlyList<MassgraveIso>> c) { _mgNote.Text = "Massgrave's list could not be read: see the log."; return; }
            if (!c.Ok) { _mgNote.Text = c.Message; return; }
            _massgrave = c.Value!;
            Fill(_mgProduct, Massgrave.Products(_massgrave), p => p);
            MassgraveLanguages();
            _mgNote.Text = "Pick an ISO and open its page. " + MgHint;
        });
    }

    private void MassgraveLanguages()
    {
        if (Picked<string>(_mgProduct) is not { } product) return;
        Fill(_mgFile, Massgrave.Files(_massgrave, product), i => i.Language);
    }

    /// <summary>Opens the chosen file's page in the browser, then looks for it in Downloads every 3 seconds.</summary>
    private void OpenMassgravePage()
    {
        if (Picked<MassgraveIso>(_mgFile) is not { } f) return;
        s.Open.Url(f.Url);
        _waiting = f.File;
        _mgNote.Text = $"Waiting for {f.File} in Downloads… (download it in the browser that just opened)";
        _watch ??= s.Every(TimeSpan.FromSeconds(3), CheckDownload);
    }

    private void CheckDownload()
    {
        if (_waiting.Length == 0 || s.IsoDownload is not { } dl) { StopWatch(); return; }
        if (dl.FindDownloaded(_waiting) is not { } hit) return;
        StopWatch();
        _waiting = "";
        SetSource(hit, $"Downloaded: {hit}");
    }

    private void StopWatch()
    {
        _watch?.Dispose();
        _watch = null;
    }

    // ---- 6 the image's lists

    private sealed record ImageLists(IReadOnlyList<ImageApp> Apps, IReadOnlyList<DismItem> Capabilities, IReadOnlyList<DismItem> Features, IReadOnlyList<DismItem> Packages);

    /// <summary>Read the image's apps (Start-AkariIsoRead): the edition mounted, its four lists read.</summary>
    public void ReadImage()
    {
        if (_image.Length == 0 || Picked<IsoEdition>(_edition) is not { } ed) { _listNote.Text = "Open the ISO and pick an edition first."; return; }
        if (s.IsoBuild is not { } build) return;
        var outDir = _outDir.Text.Trim();
        var image = _image;
        Start("IsoRead", $"Reading the apps in {ed.Name}", () =>
        {
            try
            {
                var w = IsoWork.Of(outDir);
                build.MountEdition(w, image, ed.Index);
                return new ImageLists(build.Apps(w.Mount), build.Capabilities(w.Mount),
                    [.. build.Features(w.Mount).Where(f => !f.State.Contains("Disabled", StringComparison.OrdinalIgnoreCase))], build.Packages(w.Mount));
            }
            catch (Exception e) { return Error(e); }
        }, r =>
        {
            if (r is not ImageLists l) { _listNote.Text = $"Not read: {r as string ?? "see the log"}"; return; }
            _imageApps = l.Apps;
            SetList("Apps", l.Apps.Select(a => (a.Name, a.Package)));
            SetList("Capabilities", l.Capabilities.Select(c => (c.Name, c.Name)));
            SetList("Features", l.Features.Select(f => (f.Name, f.Name)));
            SetList("Packages", l.Packages.Select(p => (p.Name, p.Name)));
            _listNote.Text = "Tick what to remove. Frameworks are left out of the list (apps need them).";
        });
    }

    private void SetList(string kind, IEnumerable<(string Label, string Value)> items)
    {
        var l = _lists[kind];
        l.Items.Children.Clear();
        foreach (var (label, value) in items.OrderBy(i => i.Label, StringComparer.CurrentCultureIgnoreCase))
        {
            var cb = Check(label, false);
            cb.Tag = value;
            l.Items.Children.Add(cb);
        }
        l.Head.Text = $"{l.Title} ({l.Items.Children.Count})";
        l.Head.Visibility = l.View.Visibility = Visibility.Visible;
    }

    private void ResetLists()
    {
        _imageApps = null;
        foreach (var l in _lists.Values)
        {
            l.Items.Children.Clear();
            l.Head.Visibility = l.View.Visibility = Visibility.Collapsed;
        }
    }

    private IEnumerable<CheckBox> ListBoxes(string kind) => _lists[kind].Items.Children.OfType<CheckBox>();

    private string[] Ticked(string kind) => [.. ListBoxes(kind).Where(c => c.IsChecked == true).Select(c => (string)c.Tag)];

    /// <summary>Select recommended: the image's apps Win11Debloat rates Safe that aren't on FR33THY's keep-list.</summary>
    public void SelectRecommended()
    {
        if (_imageApps is null) { _listNote.Text = "Read the image's apps first."; return; }
        var rec = IsoPlan.Recommended(_imageApps, s.Engine.Loaded.Tweaks.Select(t => (t.Id, (string?)t.Risk.ToString(), t.Keep))).ToHashSet(StringComparer.OrdinalIgnoreCase);
        foreach (var cb in ListBoxes("Apps")) cb.IsChecked = rec.Contains((string)cb.Tag);
    }

    public void ClearLists()
    {
        foreach (var kind in _lists.Keys)
            foreach (var cb in ListBoxes(kind)) cb.IsChecked = false;
    }

    // ---- Build

    /// <summary>Build ISO (Start-AkariIsoBuild): the choices checked, the answer file made, asked, then built.</summary>
    public void BuildIso()
    {
        _error.Text = _result.Text = "";
        _openOut.Visibility = Visibility.Collapsed;
        if (_image.Length == 0 || Picked<IsoEdition>(_edition) is not { } ed) { _error.Text = "Open the ISO and pick an edition first (step 1 and 2)."; return; }
        if (s.IsoBuild is not { } build) return;
        var picked = PickedOptions();
        if (IsoData.Check(picked, Options) is { } bad) { _error.Text = bad; return; }
        byte[]? answer = null;
        try
        {
            if (_ansLocal.IsChecked == true)
            {
                var start = (s.Unattend ??= new UnattendPage(s)).Start();
                answer = UnattendFile.Make(IsoPlan.AnswerFields(start, _user.Text, _password.Text, _skipOobe.IsChecked == true));
            }
            else if (_ansGen.IsChecked == true)
            {
                answer = (s.Unattend ??= new UnattendPage(s)).IsoAnswer(out var refused);
                if (answer is null)
                {
                    if (refused is not null) _error.Text = "The Unattend Generator's choices have a problem: open it to see what.";
                    return;
                }
            }
        }
        catch (UnattendException e) { _error.Text = $"The answer file could not be made: {e.Message}"; return; }
        var outDir = _outDir.Text.Trim();
        var iso = _isoPath.Text.Trim();
        var choices = new IsoChoices
        {
            OutDir = outDir, Iso = iso, Image = _image, Index = ed.Index, Edition = ed.Name, Options = picked,
            Apps = Ticked("Apps"), Capabilities = Ticked("Capabilities"), Features = Ticked("Features"), Packages = Ticked("Packages"),
            AkariExe = _akari.IsChecked == true ? s.AkariExe : null, Unattend = answer,
        };
        var name = IsoPlan.OutName(iso);
        var n = choices.Apps.Length + choices.Capabilities.Length + choices.Features.Length + choices.Packages.Length;
        var q = $"Build {name} from {ed.Name}?\n\n{picked.Length} options, {n} apps and features to remove. It takes 20 to 40 minutes and AkariOS can't be used meanwhile.";
        if (s.Dialogs?.Confirm(q, "Build ISO", "Cancel", "Question", Title) != true) return;
        var progress = new Posted(s, p => s.Shell.SetProgress(p.Done, p.Total, p.Step));
        Start("IsoBuild", $"Building {name}", () =>
        {
            try { return build.Build(choices, progress); }
            catch (Exception e) { return new IsoResult(false, null, Error(e)); }
        }, r =>
        {
            if (r is IsoResult { Ok: true } ok)
            {
                _result.Text = $"ISO ready: {ok.Path}";
                _openOut.Visibility = Visibility.Visible;
                _image = "";
                ResetLists();
                _edition.Items.Clear();
                _edition.IsEnabled = false;
                _openNote.Text = "The work folder was removed: open the ISO again to build another.";
                s.Dialogs?.Message($"Your ISO is ready:\n\n{ok.Path}", "Info", Title);
            }
            else _error.Text = $"Not built: {(r as IsoResult)?.Message ?? "see the log"}";
        });
    }

    // a build's progress, handed to the UI thread
    private sealed class Posted(Shell.AppServices s, Action<RunProgress> show) : IProgress<RunProgress>
    {
        public void Report(RunProgress value) => s.Post(() => show(value));
    }
}
