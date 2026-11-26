using System.IO;
using AkariOS.Core;
using AkariOS.Core.Presets;
using AkariOS.Core.Runs;
using AkariOS.Core.Sources;

namespace AkariOS.App;

/// <summary>The console's look: its title, colours, clearing (the real console, or nothing in tests).</summary>
public interface IConsoleLook
{
    void Title(string title);
    void Color(ConsoleColor color);
    void Reset();
}

/// <summary>Tests: no title, no colours.</summary>
public sealed class QuietConsole : IConsoleLook
{
    public void Title(string title) { }
    public void Color(ConsoleColor color) { }
    public void Reset() { }
}

/// <summary>The window the console runner opened (AllocConsole): black, grey text.</summary>
public sealed class RealConsole : IConsoleLook
{
    public void Title(string title) => Console.Title = title;
    public void Color(ConsoleColor color) => Console.ForegroundColor = color;

    public void Reset()
    {
        Console.BackgroundColor = ConsoleColor.Black;
        Console.ForegroundColor = ConsoleColor.Gray;
        try { Console.Clear(); } catch (IOException) { }
    }
}

/// <summary>
/// A Run in phases in a console window (Akari.ps1's -Resume and One-click branches): the banner, the live log, then
/// either the restart or the summary and "Press Enter to close this window".
/// </summary>
public sealed class RunConsole(TextWriter output, TextReader input, IConsoleLook look)
{
    /// <summary>Write-AkariBanner: the title, the logo (dots white, lines dark grey), the line under it.</summary>
    /// <summary>Write-AkariConsoleLine: one log line in the console's look (Core's ConsoleLines); a phase also goes to
    /// the window's title.</summary>
    public void Line(string message)
    {
        if (Core.Runs.ConsoleLines.Title(message) is { } title) look.Title(title);
        foreach (var s in Core.Runs.ConsoleLines.Format(message, DateTime.Now.ToString("HH:mm:ss", System.Globalization.CultureInfo.InvariantCulture)))
        {
            if (s.Text.Length == 0) { output.WriteLine(); continue; }
            look.Color(s.Color);
            output.Write(s.Text);
        }
        look.Color(ConsoleColor.Gray);
        output.WriteLine();
    }

    public void Banner(string line)
    {
        look.Title("AkariOS (Administrator) - keep this window open");
        look.Reset();
        output.WriteLine();
        var files = new EmbeddedSourceFiles();
        var art = files.Exists(Core.Runs.Banner.ArtFile) ? Core.Runs.Banner.Art(files.ReadText(Core.Runs.Banner.ArtFile)) : [];
        foreach (var row in art)
        {
            output.Write("  ");
            foreach (var (text, isLine) in Core.Runs.Banner.Strokes(row))
            {
                look.Color(isLine ? ConsoleColor.DarkGray : ConsoleColor.White);
                output.Write(text);
            }
            output.WriteLine();
        }
        // the header: what runs and the version, a rule, what to expect
        output.WriteLine();
        look.Color(ConsoleColor.White);
        output.Write($"  {line}");
        look.Color(ConsoleColor.DarkGray);
        output.WriteLine($"  AkariOS {Core.AkariInfo.Version}");
        look.Color(ConsoleColor.DarkRed);
        output.WriteLine($"  {new string(Core.Runs.ConsoleLines.Rule, Core.Runs.ConsoleLines.Width - 2)}");
        look.Color(ConsoleColor.DarkGray);
        output.WriteLine("  Keep this window open. Your PC may restart along the way; AkariOS carries on by itself.");
        look.Color(ConsoleColor.Gray);
        output.WriteLine();
    }

    /// <summary>--resume: the saved Run goes on (its user's HKCU: the engine is made for its Sid).</summary>
    public int Resume(Func<PhaseRun?> saved, Func<string, Engine> engine)
    {
        Banner("AkariOS is continuing...");
        var run = saved();
        if (run is null)
        {
            output.WriteLine("Nothing to continue.");
            return Wait(0);
        }
        var e = engine(run.Sid);
        return Finish(e, run, e.Phases().Start(run));
    }

    /// <summary>One-click: the AkariOS preset's Run from its first phase (the restore point was made in the window).</summary>
    public int OneClick(Engine e, Preset preset)
    {
        Banner("AkariOS One-click is running...");
        return RunPreset(e, preset);
    }

    /// <summary>An AkariOS ISO's first sign-in: the AkariOS preset as One-click runs it (what the image already has comes
    /// back Already), with no restore point: the PC is new.</summary>
    public int FirstSignIn(Engine e)
    {
        Banner("AkariOS is finishing setting up Windows...");
        if (e.Presets.Find(Core.Iso.IsoWizard.Preset) is not { } preset)
        {
            output.WriteLine("The AkariOS preset is missing: open AkariOS from the Start menu and run One-click.");
            return Wait(1);
        }
        // the browser is the preset's (no one to ask); a laptop gets no Ultimate Performance plan, as in One-click
        return RunPreset(e, OneClickPicks.Apply(preset, OneClickPicks.DefaultBrowser, e.System.Chassis));
    }

    private int RunPreset(Engine e, Preset preset)
    {
        e.Log.Write("Reading the apps and features on this PC...");
        var made = PresetRuns.Make(preset, e.Loaded, e.Services.Apps, revert: false, e.Services.UserSid ?? "");
        foreach (var u in made.Unknown) e.Log.WriteFile($"Warning: preset {preset.Name}: '{u}' is not a Tweak here");
        return Finish(e, made.Run, e.Phases().Start(made.Run));
    }

    private int Finish(Engine e, PhaseRun run, PhasesStatus status)
    {
        if (status == PhasesStatus.Restarting) return 0;
        Phases.Summary(run.Outcomes, e.Log);
        return Wait(run.Outcomes.Any(o => o.Kind == Core.Runs.OutcomeKind.Failed) ? 1 : 0);
    }

    private int Wait(int code)
    {
        output.WriteLine();
        look.Color(ConsoleColor.DarkGray);
        output.WriteLine("  Press Enter to close this window.");
        look.Color(ConsoleColor.Gray);
        input.ReadLine();
        return code;
    }
}
