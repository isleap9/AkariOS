using System.Globalization;

namespace AkariOS.Core;

/// <summary>
/// Akari's log (src/Core/Log.ps1): Write = a line for whoever watches (the GUI's log, the console: Write-Log),
/// WriteFile = a line in akari.log, "[2026-10-31T14:07:00] message" (Write-ErrLog). Neither throws.
/// </summary>
public interface IAkariLog
{
    void Write(string message);

    void WriteFile(string message);
}

/// <summary>The app's log: lines go to <see cref="Line"/> (or the console when nobody listens) and akari.log.</summary>
public sealed class AkariLog(string file) : IAkariLog
{
    public string File { get; } = file;

    /// <summary>The live lines (the GUI's log); with no handler they go to the console.</summary>
    public event Action<string>? Line;

    public void Write(string message)
    {
        if (string.IsNullOrWhiteSpace(message)) return;
        var m = message.TrimEnd();
        if (Line is { } handler) handler(m);
        else Console.Out.WriteLine(m);
    }

    public void WriteFile(string message)
    {
        try
        {
            Directory.CreateDirectory(Path.GetDirectoryName(File)!);
            System.IO.File.AppendAllText(File, $"[{DateTime.Now.ToString("s", CultureInfo.InvariantCulture)}] {message}{Environment.NewLine}");
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
    }
}

/// <summary>A log that keeps its lines (tests, a Run's summary).</summary>
public sealed class MemoryLog : IAkariLog
{
    private readonly List<string> _lines = [];
    private readonly List<string> _file = [];

    public IReadOnlyList<string> Lines => _lines;
    public IReadOnlyList<string> FileLines => _file;

    public void Write(string message)
    {
        if (!string.IsNullOrWhiteSpace(message)) _lines.Add(message.TrimEnd());
    }

    public void WriteFile(string message) => _file.Add(message);
}

/// <summary>The paths of the native app's own files (ADR 0007: its own, apart from the PowerShell app's).</summary>
public static class AkariPaths
{
    /// <summary>%LOCALAPPDATA%\AkariOS.Native: akari.log, state.json, lastused.json, settings.json.</summary>
    public static string UserFolder => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "AkariOS.Native");

    /// <summary>%ProgramData%\AkariOS.Native: run.json, the exe a Run in phases resumes from, files for tools.</summary>
    public static string MachineFolder => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "AkariOS.Native");

    /// <summary>%LOCALAPPDATA%\Akari\presets: shared with the PowerShell app.</summary>
    public static string PresetFolder => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Akari", "presets");

    public static string LogFile => Path.Combine(UserFolder, "akari.log");
    public static string StateFile => Path.Combine(UserFolder, "state.json");
}
