using System.IO;
using AkariOS.Core;
using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;

namespace AkariOS.App;

/// <summary>
/// The command line of AkariOS-Native.exe (src/Akari.ps1's CLI branch): --list, --apply id,id, --revert id,id,
/// --preset name|file.json, --revert-preset name|file.json, --version. Outcome lines are the output (and go to
/// akari.log), "Reboot pending" when one needs it; exit 1 when a change Failed, 2 for a usage error.
/// </summary>
public static class Cli
{
    public const string Usage = "Options: --list | --apply id,id | --revert id,id | --preset <name|file.json> | --revert-preset <name|file.json> | --version";

    /// <summary>True when the arguments ask for the console instead of the window.</summary>
    public static bool IsCli(string[] args) => args.Length > 0;

    /// <summary>Runs a command and returns the exit code. The engine is made only when the command needs it.</summary>
    public static int Run(string[] args, TextWriter output, TextWriter error, Func<Engine> engine)
    {
        var option = args[0].ToLowerInvariant();
        var rest = args.Skip(1).SelectMany(a => a.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)).ToList();
        switch (option)
        {
            case "--version":
                output.WriteLine($"AkariOS-Native {AkariInfo.Version}");
                return 0;
            case "--list":
                return List(Loaded(engine(), error), output);
            case "--apply" or "--revert" or "--preset" or "--revert-preset" when rest.Count == 0:
                error.WriteLine($"{args[0]} needs {(option.Contains("preset") ? "a preset name or file" : "Tweak ids")}. {Usage}");
                return 2;
            case "--apply" or "--revert":
                {
                    var e = Loaded(engine(), error);
                    if (!Admin(e, error)) return 2;
                    var mode = option == "--apply" ? TweakMode.Apply : TweakMode.Revert;
                    return Report(e.Runner.Run(rest, mode, e.Find), output, e.Log);
                }
            case "--preset" or "--revert-preset":
                {
                    var e = Loaded(engine(), error);
                    if (!Admin(e, error)) return 2;
                    return Preset(e, string.Join(' ', args.Skip(1)), option == "--revert-preset", output, error);
                }
            default:
                error.WriteLine($"Unknown option '{args[0]}'. {Usage}");
                return 2;
        }
    }

    // the loader's Problems: Warnings to akari.log only, Errors on stderr too (Write-AkariProblems)
    private static Engine Loaded(Engine e, TextWriter error)
    {
        foreach (var p in e.Loaded.Problems)
        {
            var line = $"{p.Level}: {p.File}: {p.Message}";
            e.Log.WriteFile(line);
            if (p.Level == "Error") error.WriteLine(line);
        }
        return e;
    }

    private static bool Admin(Engine e, TextWriter error)
    {
        if (e.IsAdmin()) return true;
        error.WriteLine("Run AkariOS-Native from an elevated console to Apply or Revert.");
        return false;
    }

    private static int List(Engine e, TextWriter output)
    {
        var states = e.States;
        var rows = e.Loaded.Tweaks
            .OrderBy(t => t.Section, StringComparer.OrdinalIgnoreCase).ThenBy(t => t.Category, StringComparer.OrdinalIgnoreCase).ThenBy(t => t.Id, StringComparer.OrdinalIgnoreCase)
            .Select(t => new[] { t.Id, t.Kind.ToString(), t.Section, t.Category, t.Risk.ToString(), states.Of(t).ToString(), Runner.NotNative(t) is null ? "yes" : "no" })
            .ToList();
        string[] head = ["Id", "Kind", "Section", "Category", "Risk", "State", "Native"];
        var widths = head.Select((h, i) => rows.Select(r => r[i].Length).Append(h.Length).Max()).ToArray();
        string Line(string[] cells) => string.Join(' ', cells.Select((c, i) => c.PadRight(widths[i]))).TrimEnd();
        output.WriteLine(Line(head));
        output.WriteLine(Line(widths.Select(w => new string('-', w)).ToArray()));
        foreach (var r in rows) output.WriteLine(Line(r));
        return 0;
    }

    private static int Preset(Engine e, string name, bool revert, TextWriter output, TextWriter error)
    {
        var p = e.Presets.Find(name);
        if (p is null)
        {
            error.WriteLine($"No preset '{name}' (built-in, in {e.Presets.UserFolder}, or a .json file).");
            return 2;
        }
        // a Run in phases restarts the PC between them: Runs in phases come with N7
        if (!revert && p.Phases.Count > 1)
        {
            error.WriteLine($"Preset {p.Name} runs in {p.Phases.Count} phases across restarts, which the native app can't do yet: use the PowerShell app for it.");
            return 2;
        }
        var resolved = Core.Presets.PresetStore.Resolve(p, e.Loaded.Tweaks, revert);
        foreach (var u in resolved.Unknown) error.WriteLine($"Warning: preset {p.Name}: '{u}' is not a Tweak here");
        return Report(e.Runner.Run(resolved.Items, e.Find), output, e.Log);
    }

    private static int Report(IReadOnlyList<Outcome> outcomes, TextWriter output, IAkariLog log)
    {
        foreach (var o in outcomes)
        {
            var line = $"{o.Kind,-9} {o.Id}  {o.Message}".TrimEnd();
            output.WriteLine(line);
            log.WriteFile(line);
        }
        if (outcomes.Any(o => o.Reboot)) output.WriteLine("Reboot pending");
        return outcomes.Any(o => o.Kind == OutcomeKind.Failed) ? 1 : 0;
    }
}
