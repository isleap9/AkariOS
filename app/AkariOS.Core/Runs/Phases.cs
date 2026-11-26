using AkariOS.Core.Machine;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Runs;

/// <summary>A Run's boot: a normal one or Safe Mode (the Boot field of run.json and of a preset's Phases).</summary>
public static class Boot
{
    public const string Normal = "Normal";
    public const string SafeMode = "SafeMode";

    public static string Words(string boot) => boot == SafeMode ? "Safe Mode" : "normal mode";
}

/// <summary>One phase of a Run: its changes, all in one boot.</summary>
public sealed class RunPhase
{
    public required string Name { get; init; }
    public required string Boot { get; init; }
    public List<PlanItem> Items { get; set; } = [];
}

/// <summary>A Run in phases across restarts (src/Core/Phases.ps1's Run): saved to run.json between them.</summary>
public sealed class PhaseRun
{
    public required string Name { get; init; }

    /// <summary>The real user's SID when the Run started: HKCU is theirs on every resume.</summary>
    public string Sid { get; init; } = "";

    /// <summary>The phase to run next.</summary>
    public int Next { get; set; }

    public List<RunPhase> Phases { get; set; } = [];
    public List<Outcome> Outcomes { get; init; } = [];

    /// <summary>Its history record (X4: Undo), made when its first phase runs; '' = none.</summary>
    public string History { get; set; } = "";
}

public enum PhasesStatus { Done, Restarting, Stopped }

/// <summary>Where a Run is kept between restarts (run.json; Clear also removes the resume entries).</summary>
public interface IRunStore
{
    void Save(PhaseRun run);
    PhaseRun? Get();
    void Clear();
}

/// <summary>The next boot and the restart (Set-AkariNextBoot, Set-AkariSafeBoot, Restart-AkariPC).</summary>
public interface IRunBoot
{
    /// <summary>The next boot is <paramref name="boot"/> and Akari resumes the Run then.</summary>
    void Next(string boot);

    /// <summary>Safe Mode on or off for the next boot; on throws when it can't be turned on.</summary>
    void SafeBoot(bool on);

    /// <summary>Restarts the PC after <paramref name="seconds"/>.</summary>
    void Restart(int seconds);
}

/// <summary>What Phases works with: the engine's parts, faked in tests.</summary>
public sealed class PhaseParts
{
    public required Func<string, Tweak?> Find { get; init; }
    public required Func<Tweak, TweakState> State { get; init; }
    public required ISystemInfo System { get; init; }
    public required Func<bool> InSafeMode { get; init; }

    /// <summary>One phase's changes (the Runner's Run of a plan).</summary>
    public required Func<IReadOnlyList<PlanItem>, IReadOnlyList<Outcome>> Plan { get; init; }

    /// <summary>A SafeMode Tweak's Prepare: null when it went well (or it has none), else its Failed Outcome.</summary>
    public required Func<Tweak, PlanItem, Outcome?> Prepare { get; init; }

    public required IRunStore Store { get; init; }
    public required IRunBoot Boot { get; init; }
    public required IAkariLog Log { get; init; }

    /// <summary>The Run history (X4): one record for the whole Run, across its restarts; null = none kept.</summary>
    public RunHistory? History { get; init; }
}

/// <summary>
/// Runs a Run from its Next phase (Start-AkariPhases). A phase whose Boot is not the current one restarts the PC into it
/// first. Before a phase that ends in a restart (a Tweak that restarts the PC, or a different Boot next), the next boot
/// is set up first, so the restart always lands in the right place. In Safe Mode a Failed change stops the Run (Safe
/// Mode is turned off, nothing resumes). A multi-phase Run ends with a restart when a change of its last phase needs one.
/// </summary>
public sealed class Phases(PhaseParts parts)
{
    /// <summary>Items whose Prepare already ran in this process (Invoke-AkariPrepare's $Item.Prepared).</summary>
    public HashSet<PlanItem> Prepared { get; } = new(ReferenceEqualityComparer.Instance);

    private IAkariLog Log => parts.Log;

    // restarts and stops also go to akari.log: the console that shows them is gone after the restart
    private void Note(string message)
    {
        Log.Write(message);
        Log.WriteFile(message);
    }

    private bool RestartsPC(string id, TweakMode mode) => parts.Find(id) is { } t && Runner.Restarts(t, mode);

    // a Safe Mode phase's Prepares, in normal mode before the restart into it (Safe Mode has no network); an item whose
    // Prepare failed leaves the phase with a Failed Outcome
    private void PrepareFor(PhaseRun run, RunPhase? phase)
    {
        if (phase is null || phase.Boot != Boot.SafeMode || parts.InSafeMode()) return;
        foreach (var item in phase.Items.ToList())
        {
            if (Prepared.Contains(item) || parts.Find(item.Id) is not { } t) continue;
            if (parts.Prepare(t, item) is { } failed)
            {
                phase.Items.Remove(item);
                run.Outcomes.Add(failed);
            }
            else Prepared.Add(item);
        }
    }

    public PhasesStatus Start(PhaseRun run)
    {
        Split(run, parts.Find, parts.State, parts.System);
        var count = run.Phases.Count;
        IReadOnlyList<Outcome> lastOut = [];
        for (var i = run.Next; i < count; i++)
        {
            var ph = run.Phases[i];
            var safe = parts.InSafeMode();
            PrepareFor(run, ph);
            if ((ph.Boot == Boot.SafeMode) != safe)
            {
                run.Next = i;
                parts.Store.Save(run);
                parts.Boot.Next(ph.Boot);
                Note($"Restarting into {Boot.Words(ph.Boot)} for: {ph.Name}");
                parts.Boot.Restart(5);
                return PhasesStatus.Restarting;
            }
            Log.Write($"Phase {i + 1} of {count}: {ph.Name}");
            Log.WriteFile($"{run.Name}: phase {i + 1} of {count}: {ph.Name}");
            var next = i + 1 < count ? run.Phases[i + 1] : null;
            PrepareFor(run, next);
            var restarts = ph.Items.Any(x => RestartsPC(x.Id, x.Mode));
            run.Next = i + 1;
            parts.Store.Save(run);
            // a phase that restarts the PC itself (DDU) sets up the next boot first; otherwise that waits until it is done
            if (next != null && restarts) parts.Boot.Next(next.Boot);
            else if (restarts && safe) parts.Boot.SafeBoot(false);
            // X4: one history record for the whole Run (Core\History.ps1's), the rows before each phase's changes
            if (parts.History is { } h)
            {
                if (run.History.Length == 0) { run.History = h.New(run.Name, DateTime.Now); parts.Store.Save(run); }
                h.AddBefore(run.History, ph.Items.Select(x => parts.Find(x.Id)));
            }
            var outcomes = parts.Plan(ph.Items);
            if (parts.History is { } hist && run.History.Length > 0) hist.AddOutcomes(run.History, outcomes);
            lastOut = outcomes;
            run.Outcomes.AddRange(outcomes);
            foreach (var o in outcomes) Log.WriteFile(OutcomeLine(o));
            parts.Store.Save(run);
            if (safe && outcomes.Any(o => o.Kind == OutcomeKind.Failed))
            {
                parts.Store.Clear();
                try { parts.Boot.SafeBoot(false); } catch (Exception) { }
                Note("Stopped in Safe Mode: a change failed (see above). Safe Mode is off again; restart when you are ready.");
                return PhasesStatus.Stopped;
            }
            // a Tweak restarted the PC: Windows is going down, the next phase resumes after it
            // (if it could not, e.g. its tool was missing, Akari restarts instead)
            if (outcomes.Any(o => o.Kind is OutcomeKind.Applied or OutcomeKind.Reverted && RestartsPC(o.Id, o.Mode)))
            {
                if (next is null) parts.Store.Clear();
                parts.Boot.Restart(5);
                return PhasesStatus.Restarting;
            }
            if (next != null && (next.Boot == Boot.SafeMode) != safe)
            {
                if (!restarts) parts.Boot.Next(next.Boot);
                Note($"Restarting into {Boot.Words(next.Boot)} for: {next.Name}");
                parts.Boot.Restart(5);
                return PhasesStatus.Restarting;
            }
        }
        parts.Store.Clear();
        if (parts.InSafeMode()) parts.Boot.SafeBoot(false);
        if (count > 1 && lastOut.Any(o => o.Reboot))
        {
            Summary(run.Outcomes, Log);
            Note("All phases done. Restarting in 15 seconds to finish.");
            parts.Boot.Restart(15);
            return PhasesStatus.Restarting;
        }
        return PhasesStatus.Done;
    }

    /// <summary>An Outcome as the CLI and akari.log print it.</summary>
    public static string OutcomeLine(Outcome o) => $"{o.Kind,-9} {o.Id}  {o.Message}";

    /// <summary>
    /// SafeMode Tweaks in a Normal phase (from Next on) move to a Safe Mode phase of their own right after it, followed
    /// by a Normal one when nothing comes after, so a phase never needs a Safe Mode detour of its own. One already in its
    /// target State stays (the Runner reports Already). Changes the Run in place (Split-AkariSafeModePhases).
    /// </summary>
    public static void Split(PhaseRun run, Func<string, Tweak?> find, Func<Tweak, TweakState> state, ISystemInfo system)
    {
        var phases = run.Phases.ToList();
        for (var i = run.Next; i < phases.Count; i++)
        {
            var p = phases[i];
            if (p.Boot == Boot.SafeMode) continue;
            var move = p.Items.Where(it =>
            {
                if (find(it.Id) is not { } t || !t.SafeMode || (t.Kind == TweakKind.Action && it.Mode == TweakMode.Revert)) return false;
                if (Requirements.Check(t, system) != null) return false;
                return t.Kind == TweakKind.Action || state(t) != (it.Mode == TweakMode.Revert ? TweakState.Default : TweakState.Optimized);
            }).ToList();
            if (move.Count == 0) continue;
            p.Items = p.Items.Where(x => !move.Contains(x)).ToList();
            phases.Insert(i + 1, new RunPhase { Name = $"{p.Name} (Safe Mode part)", Boot = Boot.SafeMode, Items = move });
            if (i + 2 >= phases.Count) phases.Add(new RunPhase { Name = "Back to normal", Boot = Boot.Normal });
            i++;
        }
        run.Phases = phases;
    }

    /// <summary>The end of a Run (Write-AkariRunSummary): how many of each Outcome, then every Failed one.</summary>
    public static void Summary(IReadOnlyList<Outcome> outcomes, IAkariLog log)
    {
        var line = SummaryLine(outcomes);
        log.Write(line);
        log.WriteFile(line);
        foreach (var f in outcomes.Where(o => o.Kind == OutcomeKind.Failed)) log.Write($"  Failed: {f.Id}: {f.Message}");
    }

    public static string SummaryLine(IReadOnlyList<Outcome> outcomes) =>
        "Done: " + string.Join(", ", Enum.GetValues<OutcomeKind>()
            .Select(k => (k, n: outcomes.Count(o => o.Kind == k)))
            .Where(x => x.n > 0)
            .Select(x => $"{x.n} {x.k.ToString().ToLowerInvariant()}"));
}
