using System.Text;
using System.Text.RegularExpressions;
using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Machine;

/// <summary>
/// A Store app's own settings hive (its Settings\settings.dat), the real user's: Import-AkariAppSettings and
/// Read-AkariAppSettings. Paths are the settings.dat file's (the Tweak finds it in the user's Local AppData).
/// </summary>
public interface IAppSettings
{
    /// <summary>The .reg text (its keys under HKEY_LOCAL_MACHINE\AkariAppHive) imported into the hive; false when there
    /// is no file or it won't load (the app holds it).</summary>
    bool Import(string dat, string regText);

    /// <summary>Its values as 'Key\Name' → bytes: empty with no file, null while the app holds it.</summary>
    IReadOnlyDictionary<string, byte[]>? Read(string dat);
}

/// <summary>A Detect row of an app setting: the value's first byte when Optimized, and Windows' (unset = Default).</summary>
public sealed record AppSettingRow(string Name, int Value, int Default);

/// <summary>The pure parts of Core\AppSetup.ps1's app settings.</summary>
public static partial class AppSettings
{
    public const string ImportRoot = @"HKEY_LOCAL_MACHINE\AkariAppHive";
    public const string ReadRoot = @"HKEY_LOCAL_MACHINE\AkariAppRead";

    /// <summary>A package family's settings.dat under the user's Local AppData.</summary>
    public static string Dat(string localAppData, string family) => Path.Combine(localAppData, "Packages", family, "Settings", "settings.dat");

    [GeneratedRegex(@"\\\r?\n\s*")]
    private static partial Regex Continued();

    [GeneratedRegex(@"^\[(.*)\]\s*$", RegexOptions.IgnoreCase)]
    private static partial Regex KeyLine();

    [GeneratedRegex(@"^""((?:[^""\\]|\\.)*)""=hex(?:\([0-9a-fA-F]+\))?:([0-9a-fA-F,]*)\s*$", RegexOptions.IgnoreCase)]
    private static partial Regex HexLine();

    [GeneratedRegex(@"\\(.)", RegexOptions.IgnoreCase)]
    private static partial Regex Escaped();

    /// <summary>ConvertFrom-AkariRegExport: a reg export's hex values under the root, 'Key\Name' (a value of the root
    /// itself by its name alone) → bytes; other keys and non-hex values left out.</summary>
    public static Dictionary<string, byte[]> Parse(string text, string root)
    {
        var values = new Dictionary<string, byte[]>(StringComparer.OrdinalIgnoreCase);
        string? key = null;
        foreach (var line in Regex.Split(Continued().Replace(text, ""), @"\r?\n"))
        {
            if (KeyLine().Match(line) is { Success: true } k)
            {
                var path = k.Groups[1].Value;
                key = path.Equals(root, StringComparison.OrdinalIgnoreCase) ? ""
                    : path.StartsWith(root + @"\", StringComparison.OrdinalIgnoreCase) ? path[(root.Length + 1)..] : null;
                continue;
            }
            if (key is null || HexLine().Match(line) is not { Success: true } m) continue;
            var name = Escaped().Replace(m.Groups[1].Value, "$1");
            var hex = m.Groups[2].Value;
            var bytes = hex.Length == 0 ? [] : hex.Split(',').Select(h => Convert.ToByte(h.Trim(), 16)).ToArray();
            values[key.Length > 0 ? $@"{key}\{name}" : name] = bytes;
        }
        return values;
    }

    /// <summary>Get-AkariAppSettingState: every row's first byte its Value = Optimized; every one unset or its Default
    /// = Default; else Custom; an unreadable hive (null) = Unknown.</summary>
    public static TweakState State(IReadOnlyDictionary<string, byte[]>? values, IEnumerable<AppSettingRow> rows)
    {
        if (values is null) return TweakState.Unknown;
        bool opt = true, def = true;
        foreach (var r in rows)
        {
            int? first = values.TryGetValue(r.Name, out var b) && b.Length > 0 ? b[0] : null;
            if (first != r.Value) opt = false;
            if (first is not null && first != r.Default) def = false;
        }
        return opt ? TweakState.Optimized : def ? TweakState.Default : TweakState.Custom;
    }
}

/// <summary>The real one: reg.exe load / import / export / unload (guarded). One hive at a time.</summary>
public sealed class RegExeAppSettings : IAppSettings
{
    private static readonly Lock Gate = new();
    private static string RegExe => Path.Combine(Environment.SystemDirectory, "reg.exe");

    public RegExeAppSettings() => SystemGuard.Check("Store apps' settings files");

    private static int Reg(params string[] arguments) => Tool.Run(RegExe, arguments).ExitCode;

    public bool Import(string dat, string regText)
    {
        if (!File.Exists(dat)) return false;
        var file = Path.Combine(Path.GetTempPath(), $"akari-import-{Environment.ProcessId}.reg");
        lock (Gate)
            try
            {
                File.WriteAllText(file, regText, Encoding.Unicode);
                if (Reg("load", @"HKLM\AkariAppHive", dat) != 0) return false;
                try { Reg("import", file); }
                finally { Reg("unload", @"HKLM\AkariAppHive"); }
                return true;
            }
            finally { File.Delete(file); }
    }

    public IReadOnlyDictionary<string, byte[]>? Read(string dat)
    {
        if (!File.Exists(dat)) return new Dictionary<string, byte[]>();
        var dir = Path.Combine(Path.GetTempPath(), $"akari-read-{Environment.ProcessId}");
        lock (Gate)
            try
            {
                Directory.CreateDirectory(dir);
                var copy = Path.Combine(dir, "settings.dat");
                try { File.Copy(dat, copy, overwrite: true); }
                catch (Exception e) when (e is IOException or UnauthorizedAccessException) { return null; }
                foreach (var log in new[] { "LOG1", "LOG2" })
                    try { File.Copy($"{dat}.{log}", $"{copy}.{log}", overwrite: true); }
                    catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
                if (Reg("load", @"HKLM\AkariAppRead", copy) != 0) return null;
                var export = Path.Combine(dir, "settings.reg");
                int code;
                try { code = Reg("export", @"HKLM\AkariAppRead", export, "/y"); }
                finally { Reg("unload", @"HKLM\AkariAppRead"); }
                if (code != 0 || !File.Exists(export)) return null;
                return AppSettings.Parse(RegReader.Decode(File.ReadAllBytes(export)), AppSettings.ReadRoot);
            }
            finally
            {
                try { Directory.Delete(dir, recursive: true); } catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
            }
    }
}
