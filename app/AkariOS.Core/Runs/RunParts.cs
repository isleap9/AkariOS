using System.Text.Json;
using System.Text.Json.Nodes;
using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Runs;

/// <summary>
/// run.json (Save- / Get- / Clear-AkariRun): the same shape as the PowerShell app's, at the native app's own path
/// (%ProgramData%\AkariOS.Native\run.json). Get is null with no file or a broken one; Clear deletes it, then onClear
/// (the resume entries).
/// </summary>
public sealed class RunStore(string path, Action onClear) : IRunStore
{
    public string Path { get; } = path;

    public static string Default => System.IO.Path.Combine(AkariPaths.MachineFolder, "run.json");

    public void Save(PhaseRun run)
    {
        var json = new JsonObject
        {
            ["Name"] = run.Name,
            ["Sid"] = run.Sid,
            ["Next"] = run.Next,
            ["Phases"] = new JsonArray([.. run.Phases.Select(p => new JsonObject
            {
                ["Name"] = p.Name,
                ["Boot"] = p.Boot,
                ["Items"] = new JsonArray([.. p.Items.Select(Item)]),
            })]),
            ["Outcomes"] = new JsonArray([.. run.Outcomes.Select(o => new JsonObject
            {
                ["Id"] = o.Id, ["Mode"] = o.Mode.ToString(), ["Outcome"] = o.Kind.ToString(), ["Reboot"] = o.Reboot, ["Message"] = o.Message,
            })]),
        };
        Directory.CreateDirectory(System.IO.Path.GetDirectoryName(Path)!);
        File.WriteAllText(Path, json.ToJsonString(new JsonSerializerOptions { WriteIndented = true }));
    }

    private static JsonObject Item(PlanItem i)
    {
        var o = new JsonObject { ["Id"] = i.Id, ["Mode"] = i.Mode.ToString() };
        if (i.Value is not null) o["Value"] = JsonNode.Parse(JsonSerializer.Serialize(i.Value, i.Value.GetType()));
        return o;
    }

    public PhaseRun? Get()
    {
        if (!File.Exists(Path)) return null;
        try
        {
            var j = JsonDocument.Parse(File.ReadAllText(Path)).RootElement;
            return new PhaseRun
            {
                Name = Str(j, "Name"),
                Sid = Str(j, "Sid"),
                Next = j.TryGetProperty("Next", out var n) && n.ValueKind == JsonValueKind.Number ? n.GetInt32() : 0,
                Phases = List(j, "Phases").Select(p => new RunPhase
                {
                    Name = Str(p, "Name"),
                    Boot = Str(p, "Boot"),
                    Items = List(p, "Items").Select(i => new PlanItem(Str(i, "Id"), Enum.Parse<TweakMode>(Str(i, "Mode"), true),
                        i.TryGetProperty("Value", out var v) ? Value(v) : null)).ToList(),
                }).ToList(),
                Outcomes = List(j, "Outcomes").Select(o => new Outcome(Str(o, "Id"), Enum.Parse<TweakMode>(Str(o, "Mode"), true),
                    Enum.Parse<OutcomeKind>(Str(o, "Outcome"), true), o.TryGetProperty("Reboot", out var r) && r.ValueKind == JsonValueKind.True, Str(o, "Message"))).ToList(),
            };
        }
        catch (Exception e) when (e is JsonException or ArgumentException or InvalidOperationException or IOException or FormatException) { return null; }
    }

    public void Clear()
    {
        try { File.Delete(Path); } catch (IOException) { }
        onClear();
    }

    private static string Str(JsonElement e, string name) =>
        e.TryGetProperty(name, out var v) && v.ValueKind == JsonValueKind.String ? v.GetString()! : "";

    // PowerShell's ConvertTo-Json writes a one-item list as the item itself
    private static IEnumerable<JsonElement> List(JsonElement e, string name) =>
        !e.TryGetProperty(name, out var v) ? [] : v.ValueKind switch
        {
            JsonValueKind.Array => v.EnumerateArray().Where(x => x.ValueKind == JsonValueKind.Object),
            JsonValueKind.Object => [v],
            _ => [],
        };

    private static object? Value(JsonElement v) => v.ValueKind switch
    {
        // object casts: a bare ?: would make every number a double
        JsonValueKind.Number => v.TryGetInt32(out var i) ? (object)i : v.TryGetInt64(out var l) ? (object)l : v.GetDouble(),
        JsonValueKind.String => v.GetString(),
        JsonValueKind.True => true,
        JsonValueKind.False => false,
        _ => null,
    };
}

/// <summary>
/// The next boot and the restart (Set-AkariNextBoot, Set-AkariSafeBoot, Restart-AkariPC): bcdedit through IBcdEdit,
/// the resume entry in the real user's RunOnce (a leading * also runs in Safe Mode; a leading ! deletes the value only
/// after the command ran). The entry starts the exe through PowerShell's Start-Process -Verb RunAs: Windows blocks a
/// startup entry that needs elevation itself.
/// </summary>
public sealed class RunBoot(RegistryEngine registry, IBcdEdit bcd, IShutdown shutdown, Func<string> target, Action<TimeSpan> sleep) : IRunBoot
{
    public const string RunOnceKey = @"HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce";
    public const string SafeName = "*!akari-native-resume";
    public const string NormalName = "!akari-native-resume";

    public static string Command(string exe) =>
        $"powershell.exe -NoProfile -WindowStyle Hidden -Command \"Start-Process -FilePath '{exe.Replace("'", "''")}' -ArgumentList '--resume' -Verb RunAs\"";

    public void Next(string boot)
    {
        ClearResume();
        SafeBoot(boot == Boot.SafeMode);
        registry.SetValue(RunOnceKey, boot == Boot.SafeMode ? SafeName : NormalName, Command(target()), "String");
    }

    public void SafeBoot(bool on)
    {
        var code = bcd.Run(on ? "/set {current} safeboot minimal" : "/deletevalue {current} safeboot");
        // turning it off when it is already off is fine
        if (code != 0 && on) throw new InvalidOperationException($"bcdedit could not turn Safe Mode on (exit code {code})");
    }

    public void Restart(int seconds)
    {
        sleep(TimeSpan.FromSeconds(seconds));
        shutdown.Restart();
    }

    public void ClearResume()
    {
        foreach (var n in new[] { SafeName, NormalName }) registry.RemoveValue(RunOnceKey, n);
    }
}

/// <summary>
/// The exe a resume starts: a copy in %ProgramData%\AkariOS.Native (the one the user ran may be in Downloads or on a
/// stick), refreshed every time a Run sets up the next boot; a developer build (not one file) is started where it is.
/// </summary>
public sealed class SelfCopy(string exe, string folder, bool developerBuild)
{
    public const string FileName = "AkariOS-Native.exe";

    /// <summary>The running exe and %ProgramData%\AkariOS.Native; a developer build's assemblies have a Location.</summary>
    // the empty Location of a single-file publish is what this reads (IL3000 warns about exactly that)
#pragma warning disable IL3000
    public static SelfCopy Live() =>
        new(Environment.ProcessPath ?? "", AkariPaths.MachineFolder, !string.IsNullOrEmpty(typeof(SelfCopy).Assembly.Location));
#pragma warning restore IL3000

    private string Copy => Path.Combine(folder, FileName);

    private bool RunningFromCopy => string.Equals(Path.GetFullPath(exe), Path.GetFullPath(Copy), StringComparison.OrdinalIgnoreCase);

    public string Target()
    {
        if (developerBuild || RunningFromCopy) return developerBuild ? exe : Copy;
        Directory.CreateDirectory(folder);
        File.Copy(exe, Copy, overwrite: true);
        return Copy;
    }

    /// <summary>On launch: the copy is deleted once no Run needs it (not while it is the one running).</summary>
    public void Clean(bool runSaved)
    {
        if (runSaved || RunningFromCopy || !File.Exists(Copy)) return;
        try { File.Delete(Copy); } catch (Exception e) when (e is IOException or UnauthorizedAccessException) { }
    }
}

/// <summary>
/// SafeMode Tweaks the Runner met outside Safe Mode: a Run of two phases (Safe Mode, then back to normal) that restarts
/// into Safe Mode now. Their Prepares already ran in the Runner.
/// </summary>
public sealed class SafeModeHandoff(Func<Phases> phases, string sid) : ISafeModeHandoff
{
    public void Start(IReadOnlyList<PlanItem> items)
    {
        var run = new PhaseRun
        {
            Name = "Safe Mode",
            Sid = sid,
            Phases =
            [
                new RunPhase { Name = "Safe Mode", Boot = Boot.SafeMode, Items = items.ToList() },
                new RunPhase { Name = "Back to normal", Boot = Boot.Normal },
            ],
        };
        var p = phases();
        foreach (var i in run.Phases[0].Items) p.Prepared.Add(i);
        p.Start(run);
    }
}
