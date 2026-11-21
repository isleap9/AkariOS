using System.Text.Json;
using AkariOS.Core.Runs;

namespace AkariOS.Core.Iso;

/// <summary>
/// The ISO Builder's engine (src/Core/Iso.ps1, Iso/Image.ps1): an ISO opened into &lt;out&gt;\AkariIso (its files
/// copied, its editions read), an edition exported and mounted, the build (apps, features, capabilities and packages
/// removed, the hives written, files removed, AkariOS and the answer file added, the image saved and compressed,
/// boot.wim patched, the ISO made with oscdimg), a mount left behind discarded. Everything it reaches is in
/// <see cref="IsoParts"/>; nothing touches this PC's own Windows.
/// </summary>
public sealed partial class IsoBuild(IsoParts p)
{
    // ---- the work folder

    /// <summary>Copies the ISO's files to &lt;out&gt;\AkariIso\Media (a previous build's folder cleared first) and
    /// reads its editions (Open-AkariIsoSource). Throws an <see cref="IsoException"/> with a message for the user.</summary>
    public IsoSource Open(string iso, string outDir)
    {
        var (free, format) = p.Drive(outDir);
        if (IsoPlan.Space(free, format) is { } msg) throw new IsoException(msg);
        var w = IsoWork.Of(outDir);
        ClearLeftover();
        if (Directory.Exists(w.Root)) DeleteTree(w.Root);
        Directory.CreateDirectory(w.Media);
        Directory.CreateDirectory(w.Mount);
        p.Log.Write($"Copying {iso}");
        var root = p.Disk.Mount(iso);
        try { CopyTree(root, w.Media); }
        finally { p.Disk.Dismount(iso); }
        // files copied off a disc are read-only
        foreach (var f in Directory.EnumerateFiles(w.Media, "*", SearchOption.AllDirectories)) File.SetAttributes(f, FileAttributes.Normal);
        var image = InstallImage(w.Media) ?? throw new IsoException("This ISO has no sources\\install.wim, install.esd or install.swm: it isn't a Windows setup ISO.");
        var editions = IsoPlan.Editions(p.Image.Images(image));
        if (!editions.Any(e => e.Supported)) throw new IsoException("This ISO isn't Windows 11: the ISO Builder only works on Windows 11 images.");
        return new IsoSource(w, image, editions);
    }

    private static string? InstallImage(string media) =>
        new[] { "install.wim", "install.esd", "install.swm" }.Select(n => Path.Combine(media, "sources", n)).FirstOrDefault(Exists);

    private static bool Exists(string path) => File.Exists(path) || Directory.Exists(path);

    private static void CopyTree(string from, string to)
    {
        foreach (var d in Directory.EnumerateDirectories(from, "*", SearchOption.AllDirectories))
            Directory.CreateDirectory(Path.Combine(to, Path.GetRelativePath(from, d)));
        foreach (var f in Directory.EnumerateFiles(from, "*", SearchOption.AllDirectories))
            File.Copy(f, Path.Combine(to, Path.GetRelativePath(from, f)), overwrite: true);
    }

    /// <summary>Remove-Item -Recurse -Force: read-only files too.</summary>
    private static void DeleteTree(string folder)
    {
        foreach (var f in Directory.EnumerateFiles(folder, "*", SearchOption.AllDirectories)) File.SetAttributes(f, FileAttributes.Normal);
        Directory.Delete(folder, recursive: true);
    }

    // ---- the marker: what is mounted (a crash or power loss leaves it)

    private sealed record MarkerData(string Mount, string Image, int Index);

    private MarkerData? Marker()
    {
        if (!File.Exists(p.Marker)) return null;
        try
        {
            var j = JsonDocument.Parse(File.ReadAllText(p.Marker)).RootElement;
            return new MarkerData(j.GetProperty("Mount").GetString() ?? "", j.TryGetProperty("Image", out var i) ? i.GetString() ?? "" : "",
                j.TryGetProperty("Index", out var x) && x.ValueKind == JsonValueKind.Number ? x.GetInt32() : 0);
        }
        catch (Exception e) when (e is JsonException or KeyNotFoundException or InvalidOperationException or IOException) { return null; }
    }

    private void SetMarker(string mount, string image = "", int index = 0)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(p.Marker)!);
        File.WriteAllText(p.Marker, JsonSerializer.Serialize(new MarkerData(mount, image, index)));
    }

    private void ClearMarker()
    {
        try { File.Delete(p.Marker); } catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
    }

    /// <summary>True when this edition is the one mounted in the work folder; without an image, any mount there.</summary>
    private bool Mounted(IsoWork w, string image = "", int index = 0)
    {
        var m = Marker();
        if (m is null || !m.Mount.Equals(w.Mount, StringComparison.OrdinalIgnoreCase)) return false;
        if (image.Length == 0) return true;
        return m.Image.Equals(image, StringComparison.OrdinalIgnoreCase) && m.Index == index;
    }

    /// <summary>The chosen edition exported to &lt;out&gt;\AkariIso\install.wim and mounted (Mount-AkariIsoEdition:
    /// once; another edition mounted there is discarded first).</summary>
    public void MountEdition(IsoWork w, string image, int index)
    {
        if (Mounted(w, image, index)) return;
        if (Marker() is not null) ClearLeftover();
        try { File.Delete(w.Wim); } catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
        p.Image.Export(image, index, w.Wim, "fast");
        Directory.CreateDirectory(w.Mount);
        SetMarker(w.Mount, image, index);
        try { p.Image.Mount(w.Wim, 1, w.Mount); }
        catch
        {
            p.Image.Discard(w.Mount);
            ClearMarker();
            throw;
        }
    }

    /// <summary>A mount left behind by a build that didn't finish: hives unloaded, image discarded
    /// (Clear-AkariIsoLeftover). On launch; never throws.</summary>
    public void ClearLeftover()
    {
        var m = Marker();
        if (m is null) return;
        try
        {
            p.Log.WriteFile($"ISO Builder: discarding the image left mounted at {m.Mount}");
            UnloadHives(AllHives);
            p.Image.Discard(m.Mount);
        }
        catch (Exception e) { p.Log.WriteFile($"ISO Builder: leftover cleanup failed: {e.Message}"); }
        ClearMarker();
    }

    // ---- the image's hives

    private static IReadOnlyList<string> AllHives => [.. IsoData.Hives.Select(h => h.Name)];

    /// <summary>Loads the hives the mounted image has: their names.</summary>
    private List<string> LoadHives(string mount)
    {
        var loaded = new List<string>();
        foreach (var (name, file) in IsoData.Hives)
        {
            var f = Path.Combine(mount, file);
            if (!Exists(f)) continue;
            if (p.Hives.Load(name, f)) loaded.Add(name);
            else p.Log.Write($"Could not load the image's {name} hive");
        }
        return loaded;
    }

    /// <summary>A few tries each: a handle still open keeps a hive loaded for a moment.</summary>
    private void UnloadHives(IEnumerable<string> names)
    {
        foreach (var h in names)
            for (var i = 0; i < 3; i++)
            {
                if (p.Hives.Unload(h)) break;
                if (i < 2) p.Sleep(500);
            }
    }

    // ---- the build

    /// <summary>Invoke-AkariIsoBuild: the steps of <see cref="IsoPlan.Steps"/>, progress per step and each step's
    /// operations through <paramref name="operations"/>; a failure discards the image, never left mounted. Either way
    /// a report (<see cref="IsoReport"/>) goes next to the ISO and on the result.</summary>
    public IsoResult Build(IsoChoices c, IProgress<RunProgress>? progress = null, IProgress<IsoOperation>? operations = null)
    {
        _ops = operations;
        _stageOps.Clear();
        var started = DateTime.Now;
        var stages = new List<IsoReportStage>();
        var stageClock = new System.Diagnostics.Stopwatch();
        void EndStage(IsoStep step, string state) =>
            stages.Add(new IsoReportStage(step.Id, step.Text, state, Math.Round(stageClock.Elapsed.TotalSeconds, 1), [.. _stageOps]));
        var all = IsoData.Options(p.Files);
        if (IsoData.Check(IsoPlan.List(c.Options), all) is { } bad) return new IsoResult(false, null, bad);
        var picked = IsoData.Picked(c.Options, all);
        IReadOnlyList<IsoGroup> groups;
        try { groups = c.Groups is null ? [] : IsoWizard.Picked(c.Groups, IsoWizard.Groups(p.Files)); }
        catch (IsoException e) { return new IsoResult(false, null, e.Message); }
        var w = IsoWork.Of(c.OutDir);
        var output = Path.Combine(c.OutDir, IsoPlan.OutName(c.Iso));
        // the wizard's groups stand in for zISO's always-on data
        var always = c.Groups is null ? IsoData.Always(p.Files) : new IsoAlways([], [], [], []);
        var steps = IsoPlan.Steps(c, picked, groups);
        string? oscdimg = null;
        var sha = "";
        try
        {
            for (var i = 0; i < steps.Count; i++)
            {
                var s = steps[i];
                (_stage, _current) = (i, s);
                _stageOps.Clear();
                stageClock.Restart();
                progress?.Report(new RunProgress(i, steps.Count, s.Text));
                p.Log.Write(s.Text);
                switch (s.Id)
                {
                    case "Adk": oscdimg = Oscdimg(); break;
                    case "Mount": MountEdition(w, c.Image, c.Index); break;
                    case "Apps":
                        {
                            // the user's picks plus the image's apps an option names (Defender's Security app, the AI apps)
                            var patterns = picked.SelectMany(o => o.Apps).Concat(IsoPlan.List(c.AppPatterns)).ToList();
                            var fromOptions = Apps(w.Mount).Where(a => patterns.Any(x => PsLike(a.Name, x))).Select(a => a.Package);
                            RemoveApps(w.Mount, IsoData.Resolve([.. IsoPlan.List(c.Apps), .. fromOptions], [], []));
                            break;
                        }
                    case "Features":
                        {
                            var patterns = picked.SelectMany(o => o.Features).Concat(groups.SelectMany(x => x.Features)).ToList();
                            IReadOnlyList<string> have = patterns.Count > 0 ? [.. p.Image.Features(w.Mount).Select(f => f.Name)] : [];
                            var features = IsoData.Resolve(IsoPlan.List(c.Features), patterns, have);
                            if (c.Settings.Turbo) RemoveFeaturesAtOnce(w.Mount, features);
                            else RemoveItems(w.Mount, "Feature", features);
                            break;
                        }
                    case "Capabilities": RemoveItems(w.Mount, "Capability", Names(IsoPlan.List(c.Capabilities), groups.SelectMany(x => x.Capabilities))); break;
                    case "Packages": RemoveItems(w.Mount, "Package", Names(IsoPlan.List(c.Packages), groups.SelectMany(x => x.Packages))); break;
                    case "Registry":
                        {
                            IReadOnlyList<Data.PsHashtable> rows =
                                [.. always.Requirements, .. always.Registry, .. picked.SelectMany(o => o.Registry), .. groups.SelectMany(x => x.Registry)];
                            Op($"Write {rows.Count} settings", () =>
                            {
                                WriteImageRegistry(w.Mount, rows, [.. picked.SelectMany(o => o.RemoveKeys), .. groups.SelectMany(x => x.RemoveKeys)]);
                                return (IsoOpState.Done, "");
                            });
                            break;
                        }
                    case "Bake": BakeAkariOS(w.Mount, c); break;
                    case "Files":
                        foreach (var path in always.Remove.Concat(picked.SelectMany(o => o.Remove)).Concat(groups.SelectMany(x => x.Remove)))
                            Op(path, () => RemovePaths(w.Mount, [path]) is var n and > 0 ? (IsoOpState.Done, $"{n} removed") : (IsoOpState.Skipped, "Not in this image"));
                        break;
                    case "AkariOS": Op("AkariOS-Native.exe and its shortcuts", () => { CopyAkariOS(w.Mount, c.AkariExe!); return (IsoOpState.Done, ""); }); break;
                    case "Answer": Op("autounattend.xml", () => { File.WriteAllBytes(Path.Combine(w.Media, "autounattend.xml"), c.Unattend!); return (IsoOpState.Done, ""); }); break;
                    case "NetFx3":
                        Op(".NET Framework 3.5", () =>
                        {
                            var sxs = Path.Combine(w.Media, @"sources\sxs");
                            if (!Exists(sxs)) { p.Log.Write(@"No sources\sxs on the ISO: .NET Framework 3.5 left out"); return (IsoOpState.Skipped, @"The ISO has no sources\sxs"); }
                            var code = p.Image.Dism([$"/Image:{w.Mount}", "/Enable-Feature", "/FeatureName:NetFx3", "/All", "/LimitAccess", $"/Source:{sxs}"]);
                            if (code == 0) return (IsoOpState.Done, "");
                            p.Log.Write($".NET Framework 3.5 was not added (DISM exit code {code})");
                            return (IsoOpState.Failed, $"DISM exit code {code}");
                        });
                        break;
                    case "Cleanup":
                        Op("Component store cleanup", () =>
                        {
                            var code = p.Image.Dism([$"/Image:{w.Mount}", "/Cleanup-Image", "/StartComponentCleanup", "/ResetBase"]);
                            if (code == 0) return (IsoOpState.Done, "");
                            p.Log.Write($"Component cleanup skipped (DISM exit code {code}, pending operations)");
                            return (IsoOpState.Skipped, $"Pending operations (DISM exit code {code}): the image may be larger");
                        });
                        break;
                    case "Leftovers": RemoveLeftovers(w.Mount); break;
                    case "Commit": p.Image.Commit(w.Mount); break;
                    case "Compress":
                        {
                            var sources = Path.Combine(w.Media, "sources");
                            if (Directory.Exists(sources))
                                foreach (var old in Directory.EnumerateFiles(sources, "install*"))
                                    if (Path.GetExtension(old).ToLowerInvariant() is ".wim" or ".esd" or ".swm") File.Delete(old);
                            var (file, mode) = c.Settings.Compression switch
                            {
                                IsoCompression.Recovery => ("install.esd", "recovery"),
                                IsoCompression.Fast => ("install.wim", "fast"),
                                _ => ("install.wim", "max"),
                            };
                            p.Image.Export(w.Wim, 1, Path.Combine(sources, file), mode);
                            TryDelete(w.Wim);
                            break;
                        }
                    case "Boot":
                        {
                            var boot = Path.Combine(w.Media, @"sources\boot.wim");
                            if (!Exists(boot) || p.Image.Images(boot).Count < 2) { p.Log.Write("No setup image in boot.wim: left as it is"); break; }
                            p.Image.Mount(boot, 2, w.Mount);
                            WriteImageRegistry(w.Mount, [.. always.Requirements, .. always.Boot, .. groups.SelectMany(x => x.Boot)], []);
                            p.Image.Commit(w.Mount);
                            ClearMarker();
                            break;
                        }
                    case "NoSxs":
                        Op(@"sources\sxs", () =>
                        {
                            var sxs = Path.Combine(w.Media, @"sources\sxs");
                            if (!Directory.Exists(sxs)) return (IsoOpState.Skipped, "Not on this ISO");
                            DeleteTree(sxs);
                            return (IsoOpState.Done, "");
                        });
                        break;
                    case "Iso":
                        {
                            TryDelete(output);
                            var code = p.Exe.Run(oscdimg!, JoinArgs(IsoPlan.OscdimgArgs(w.Media, output, Exists))).ExitCode;
                            if (code != 0) throw new IsoException($"oscdimg failed (exit code {code})");
                            Op("SHA-256 of the ISO", () => (sha = IsoReport.Sha256Of(output)).Length > 0 ? (IsoOpState.Done, sha) : (IsoOpState.Skipped, "No ISO to check"));
                            break;
                        }
                    case "Tidy":
                        ClearMarker();
                        try { if (Directory.Exists(w.Root)) DeleteTree(w.Root); }
                        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
                        break;
                }
                EndStage(s, "Done");
            }
            progress?.Report(new RunProgress(steps.Count, steps.Count, "Done"));
            p.Log.Write($"ISO ready: {output}");
            var report = WriteReport(Report(true, "") with { Size = File.Exists(output) ? new FileInfo(output).Length : 0, Sha256 = sha });
            return new IsoResult(true, output, "") { Report = report };
        }
        catch (Exception e)
        {
            if (_current is { } failed) EndStage(failed, "Failed");
            foreach (var rest in steps.Skip(stages.Count)) stages.Add(new IsoReportStage(rest.Id, rest.Text, "Not run", 0, []));
            var report = WriteReport(Report(false, e.Message));
            p.Log.Write($"ISO build failed: {e.Message}");
            p.Log.WriteFile($"ISO Builder: {e.Message}");
            UnloadHives(AllHives);
            if (Marker() is not null)
            {
                p.Image.Discard(w.Mount);
                ClearMarker();
            }
            return new IsoResult(false, null, e.Message) { Report = report };
        }
        finally
        {
            _ops = null;
            _current = null;
        }

        IsoReport Report(bool ok, string message) => new()
        {
            Started = started, Finished = DateTime.Now, Ok = ok, Message = message, Source = c.Iso, Edition = c.Edition, Iso = output,
            Settings = c.Settings, Stages = stages,
        };
    }

    // ---- the build's operations and report

    private IProgress<IsoOperation>? _ops;
    private int _stage;
    private IsoStep? _current;
    private readonly List<IsoReportOperation> _stageOps = [];

    /// <summary>One operation of the running stage: Running, then how it ended (a throw = Failed, and the build
    /// fails as before). No log line: the build's log stays the port's.</summary>
    private void Op(string name, Func<(IsoOpState State, string Note)> work)
    {
        var clock = System.Diagnostics.Stopwatch.StartNew();
        _ops?.Report(new IsoOperation(_stage, name, IsoOpState.Running, TimeSpan.Zero));
        (IsoOpState State, string Note) r;
        try { r = work(); }
        catch (Exception e)
        {
            Ended(name, IsoOpState.Failed, clock.Elapsed, e.Message);
            throw;
        }
        Ended(name, r.State, clock.Elapsed, r.Note);
    }

    private void Ended(string name, IsoOpState state, TimeSpan elapsed, string note)
    {
        _ops?.Report(new IsoOperation(_stage, name, state, elapsed, note));
        _stageOps.Add(new IsoReportOperation(name, state, Math.Round(elapsed.TotalSeconds, 1), note));
    }

    /// <summary>The report next to the ISO; never fails the build (a folder that can't be written = no file).</summary>
    private static IsoReport WriteReport(IsoReport report)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(report.Iso)!);
            File.WriteAllText(IsoReport.FileFor(report.Iso), report.ToJson());
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or ArgumentException) { }
        return report;
    }

    private static bool PsLike(string text, string pattern) => Data.PsSemantics.Like(text, pattern);

    private static void TryDelete(string file)
    {
        try { File.Delete(file); } catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
    }

    /// <summary>Arguments as one command line, as PowerShell passes them to a program: one with spaces quoted.</summary>
    internal static string JoinArgs(IEnumerable<string> arguments) =>
        string.Join(' ', arguments.Select(a => a.Length == 0 || a.Contains(' ') ? $"\"{a}\"" : a));
}
