using System.IO.Compression;
using System.Text;
using System.Text.Json;
using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Update;

namespace AkariOS.Core.Iso;

/// <summary>What the ISO Builder's downloads reach: the network (UUP Dump's API and package, Massgrave's pages), the
/// converter (through <see cref="IExe.Lines"/>), the log, the output drive's space, a pause (the API's retries), the
/// real user's Downloads folder (where a browser saves Massgrave's ISO).</summary>
public sealed record IsoDownloadParts
{
    public required IHttp Http { get; init; }
    public required IExe Exe { get; init; }
    public required IAkariLog Log { get; init; }
    public required string Windows { get; init; }
    public required Func<string, (long Free, string Format)> Drive { get; init; }

    /// <summary>Milliseconds.</summary>
    public required Action<int> Sleep { get; init; }

    public required Func<string?> Downloads { get; init; }

    /// <summary>The real ones: the engine's downloads, programs, log and registry (the real user's Downloads).</summary>
    public static IsoDownloadParts Live(IHttp http, IExe exe, IAkariLog log, RegistryEngine registry) => new()
    {
        Http = http, Exe = exe, Log = log, Windows = Environment.GetFolderPath(Environment.SpecialFolder.Windows),
        Drive = path =>
        {
            var d = new DriveInfo(Path.GetPathRoot(Path.GetFullPath(path))!);
            return (d.AvailableFreeSpace, d.DriveFormat);
        },
        Sleep = Thread.Sleep,
        Downloads = () => UserFolders.Get(registry, "Downloads"),
    };
}

/// <summary>An answer that never throws: the value, or why there is none.</summary>
public sealed record UupAnswer<T>(bool Ok, T? Value, string Message);

/// <summary>A language UUP Dump has a build in: its code (en-us) and name.</summary>
public sealed record UupLanguage(string Code, string Name);

/// <summary>
/// The ISO Builder's downloads (src/Core/IsoDownload.ps1): UUP Dump's API with retries (the newest release build of a
/// version, its languages, its editions), its converter package run into a Windows 11 ISO, Massgrave's catalogue, the
/// ISO a browser saved from it. Nothing here throws: each answer says what went wrong.
/// </summary>
public sealed class IsoDownload(IsoDownloadParts p)
{
    /// <summary>Seconds between the API's tries ($AkariUupRetryDelay).</summary>
    public const int RetryDelay = 5;

    private const string ApiRoot = "https://api.uupdump.net/";

    private static UupAnswer<T> No<T>(string message) => new(false, default, message);

    /// <summary>A UUP Dump API call (Invoke-AkariUupApi): three tries, a pause between; its 'response', or the error it
    /// answers.</summary>
    public UupAnswer<JsonElement> Api(string name, IReadOnlyDictionary<string, string> query)
    {
        var url = $"{ApiRoot}{name}.php?" + string.Join("&", query.Select(q => $"{Uri.EscapeDataString(q.Key)}={Uri.EscapeDataString(q.Value)}"));
        var last = "";
        for (var i = 0; i < 3; i++)
        {
            if (i > 0) p.Sleep(RetryDelay * 1000);
            try
            {
                var root = JsonDocument.Parse(p.Http.Text(url)).RootElement;
                var response = root.TryGetProperty("response", out var r) ? r.Clone() : default;
                if (Uup.Field(response, "error") is { Length: > 0 } error) return No<JsonElement>($"UUP Dump: {error}");
                return new(true, response, "");
            }
            catch (Exception e) { last = e.Message; }
        }
        return No<JsonElement>($"UUP Dump didn't answer: {last}");
    }

    /// <summary>The newest release build of a version ('25H2'; Get-AkariUupBuild).</summary>
    public UupAnswer<UupBuild> Build(string version)
    {
        var n = Uup.Versions.FirstOrDefault(v => v.Version.Equals(version, StringComparison.OrdinalIgnoreCase)).Build;
        if (n is null) return No<UupBuild>($"Unknown Windows 11 version: {version}");
        var r = Api("listid", new Dictionary<string, string> { ["search"] = $"windows 11 {n} amd64", ["sortByDate"] = "1" });
        if (!r.Ok) return No<UupBuild>(r.Message);
        var builds = r.Value.ValueKind == JsonValueKind.Object && r.Value.TryGetProperty("builds", out var b) ? Uup.Builds(b) : [];
        var build = Uup.Select(builds, n);
        return build is null ? No<UupBuild>($"UUP Dump has no Windows 11 {version} release build ({n}) right now.") : new(true, build, "");
    }

    /// <summary>A build's languages, by name (Get-AkariUupLanguages).</summary>
    public UupAnswer<IReadOnlyList<UupLanguage>> Languages(string id)
    {
        var r = Api("listlangs", new Dictionary<string, string> { ["id"] = id });
        if (!r.Ok) return No<IReadOnlyList<UupLanguage>>(r.Message);
        IReadOnlyList<UupLanguage> items = r.Value.ValueKind == JsonValueKind.Object && r.Value.TryGetProperty("langFancyNames", out var names) && names.ValueKind == JsonValueKind.Object
            ? [.. names.EnumerateObject().Select(x => new UupLanguage(x.Name, Uup.Field(names, x.Name)))
                .OrderBy(x => x.Name, StringComparer.CurrentCulture).ThenBy(x => x.Code, StringComparer.Ordinal)]
            : [];
        return new(true, items, "");
    }

    /// <summary>The editions a build and language can become (Get-AkariUupEditions).</summary>
    public UupAnswer<IReadOnlyList<UupTarget>> Editions(string id, string lang)
    {
        var r = Api("listeditions", new Dictionary<string, string> { ["id"] = id, ["lang"] = lang });
        if (!r.Ok) return No<IReadOnlyList<UupTarget>>(r.Message);
        var fancy = r.Value.ValueKind == JsonValueKind.Object && r.Value.TryGetProperty("editionFancyNames", out var f) ? f : default;
        return new(true, Uup.Targets(fancy), "");
    }

    /// <summary>Downloads and builds the ISO into <paramref name="outDir"/> (Save-AkariUupIso): UUP Dump's converter
    /// package, its ConvertConfig.ini set as zISO sets it, the converter run (its output into the log; Microsoft's
    /// files are several GB), the ISO moved to &lt;out&gt;\Windows11_&lt;version&gt;_&lt;edition&gt;_&lt;lang&gt;.iso.</summary>
    public IsoResult SaveUup(string version, UupBuild build, string lang, UupTarget target, string outDir)
    {
        var work = Path.Combine(outDir, "AkariUup");
        var zip = work + ".zip";
        try
        {
            var (free, format) = p.Drive(outDir);
            if (IsoPlan.Space(free, format) is { } msg) throw new IsoException(msg);
            Remove(work);
            Remove(zip);
            p.Log.Write($"Getting UUP Dump's package for Windows 11 {version} {target.Label} ({lang}), build {build.Build}");
            var url = $"https://uupdump.net/get.php?id={build.Id}&pack={lang}&edition={target.Code.ToLowerInvariant()}";
            p.Http.Post(url, Uup.PackageBody(target.Virtual), zip);
            ZipFile.ExtractToDirectory(zip, work, overwriteFiles: true);
            var ini = Path.Combine(work, "ConvertConfig.ini");
            if (!File.Exists(ini)) throw new IsoException("UUP Dump's package has no ConvertConfig.ini.");
            WriteAscii(ini, Uup.Config(File.ReadAllLines(ini), target.Virtual));
            p.Log.Write("Downloading Microsoft's files and building the ISO (this takes a while)");
            var code = p.Exe.Lines(Path.Combine(p.Windows, "System32", "cmd.exe"), "/c uup_download_windows.cmd", work, p.Log.Write);
            if (code != 0) throw new IsoException($"UUP Dump's converter failed (exit code {code}).");
            var iso = Directory.EnumerateFiles(work, "*.iso").Order(StringComparer.OrdinalIgnoreCase).FirstOrDefault()
                ?? throw new IsoException("UUP Dump's converter made no ISO.");
            var dest = Path.Combine(outDir, Uup.IsoName(version, target.Label, lang));
            Remove(dest);
            File.Move(iso, dest);
            p.Log.Write($"ISO downloaded: {dest}");
            return new IsoResult(true, dest, "");
        }
        catch (Exception e)
        {
            p.Log.WriteFile($"ISO Builder (UUP Dump): {e.Message}");
            return new IsoResult(false, null, e.Message);
        }
        finally
        {
            Remove(work);
            Remove(zip);
        }
    }

    private static void Remove(string path)
    {
        try
        {
            if (Directory.Exists(path)) Directory.Delete(path, recursive: true);
            else if (File.Exists(path)) File.Delete(path);
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
    }

    /// <summary>5.1's Set-Content -Encoding Ascii: each line and a CRLF, anything outside ASCII as '?'.</summary>
    private static void WriteAscii(string file, IEnumerable<string> lines) =>
        File.WriteAllText(file, string.Concat(lines.Select(l => l + "\r\n")), Encoding.ASCII);

    /// <summary>Massgrave's Windows 11 ISOs from both pages (Get-AkariMassgraveCatalogue).</summary>
    public UupAnswer<IReadOnlyList<MassgraveIso>> Catalogue()
    {
        try
        {
            var items = new List<MassgraveIso>();
            foreach (var u in Massgrave.Pages) items.AddRange(Massgrave.Read(p.Http.Text(u)));
            return items.Count == 0
                ? No<IReadOnlyList<MassgraveIso>>("Massgrave's pages list no Windows 11 ISO (their layout may have changed).")
                : new(true, items, "");
        }
        catch (Exception e) { return No<IReadOnlyList<MassgraveIso>>($"Couldn't read Massgrave's list: {e.Message}"); }
    }

    /// <summary>The file a browser saved in the real user's Downloads (or <paramref name="folder"/>): the file itself
    /// or a copy it renamed ("name (1).iso"), the newest; null while it isn't there (Find-AkariDownloadedIso).</summary>
    public string? FindDownloaded(string file, string? folder = null)
    {
        folder ??= p.Downloads();
        if (string.IsNullOrEmpty(folder) || !Directory.Exists(folder)) return null;
        var stem = Path.GetFileNameWithoutExtension(file);
        return new DirectoryInfo(folder).EnumerateFiles("*.iso")
            .Where(f => f.Extension.Equals(".iso", StringComparison.OrdinalIgnoreCase))
            .Where(f => f.Name.Equals(file, StringComparison.OrdinalIgnoreCase) || PsSemantics.Like(Path.GetFileNameWithoutExtension(f.Name), stem + " (*)"))
            .OrderByDescending(f => f.LastWriteTimeUtc)
            .FirstOrDefault()?.FullName;
    }
}
