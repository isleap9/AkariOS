using System.Text.RegularExpressions;
using AkariOS.Core.Data;
using AkariOS.Core.Machine;
using AkariOS.Core.Registry;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Runs;

/// <summary>What happened to one Tweak in a Run (Glossary: Outcome).</summary>
public enum OutcomeKind { Applied, Reverted, Already, Skipped, Failed }

public sealed record Outcome(string Id, TweakMode Mode, OutcomeKind Kind, bool Reboot = false, string Message = "");

/// <summary>One change of a Run: Apply or Revert, a Choice's value (null = Recommended), its preset Phase (index).</summary>
public sealed record PlanItem(string Id, TweakMode Mode, object? Value = null, int Phase = 0);

/// <summary>How far a Run is (the status bar: "label (n of total): step").</summary>
public sealed record RunProgress(int Done, int Total, string Step);

/// <summary>SafeMode Tweaks outside Safe Mode: a Run in phases restarts into Safe Mode for them and back (N7).</summary>
public interface ISafeModeHandoff
{
    void Start(IReadOnlyList<PlanItem> items);
}

/// <summary>
/// Applies or Reverts Tweaks and returns one Outcome per item (src/Core/Runner.ps1): Applied / Reverted, Already
/// (its State already matches), Skipped (a Requires unmet, an Action's Revert, a restart that has to wait) or Failed.
/// A Failed Tweak never stops the Run. Changes that restart the PC run last, after Explorer's restart, one per Run;
/// Explorer restarts once when a Tweak with Explorer = $true was Applied or Reverted; SafeMode Tweaks outside Safe
/// Mode get their Prepare now and go to the handoff.
/// </summary>
public sealed partial class Runner(TweakContext context, States states, IRememberedState remembered, IExplorer explorer,
    ISafeModeHandoff? safeMode = null, Func<bool>? inSafeMode = null)
{
    private IAkariLog Log => context.Log;

    private static Outcome Outcome(Tweak t, TweakMode mode, OutcomeKind kind, bool reboot = false, string message = "") =>
        new(t.Id, mode, kind, reboot, message);

    /// <summary>Why the native app can't run it yet, or null (its C#, an engine kind or winget still to come).</summary>
    public static string? NotNative(Tweak t)
    {
        if (t.EntryKind is { } kind && !Parity.NativeEntryKinds.Contains(kind.Name))
            return "the native app can't do this list's changes yet";
        if (t.Winget.Count > 0) return "the native app can't install with winget yet";
        if (!t.Native) return "only the PowerShell app can run it yet (its C# is still to come)";
        return null;
    }

    /// <summary>One Tweak (Invoke-AkariTweak). Value: Apply a Choice to this value instead of its Recommended one.</summary>
    public Outcome Run(Tweak t, TweakMode mode, object? value = null)
    {
        if (value is not null && t.Kind != TweakKind.Choice)
        {
            Log.Write($"Failed: {t.Name} (Value is only for Choices)");
            return Outcome(t, mode, OutcomeKind.Failed, message: "Value is only for Choices");
        }
        if (Requirements.Check(t, context.System) is { } why)
        {
            Log.Write($"Skipped: {t.Name} ({why})");
            return Outcome(t, mode, OutcomeKind.Skipped, message: why);
        }
        if (t.Kind == TweakKind.Action && mode == TweakMode.Revert)
        {
            Log.Write($"Skipped: {t.Name} (Action has no Revert)");
            return Outcome(t, mode, OutcomeKind.Skipped, message: "Action has no Revert");
        }
        if (NotNative(t) is { } missing)
        {
            Log.Write($"Failed: {t.Name} ({missing})");
            return Outcome(t, mode, OutcomeKind.Failed, message: missing);
        }

        var want = mode == TweakMode.Apply ? TweakState.Optimized : TweakState.Default;
        if (IsAlready(t, mode, value, want))
        {
            Log.Write($"Already: {t.Name}");
            return Outcome(t, mode, OutcomeKind.Already);
        }

        try { Change(t, mode, value); }
        catch (Exception e)
        {
            Log.Write($"Failed: {t.Name}: {e.Message}");
            return Outcome(t, mode, OutcomeKind.Failed, message: e.Message);
        }
        if (t.Kind == TweakKind.Toggle && !t.Has("Detect") && t.Registry is null && !t.RowsAreCode) remembered.Set(t.Id, mode == TweakMode.Apply);
        var done = mode == TweakMode.Apply ? OutcomeKind.Applied : OutcomeKind.Reverted;
        Log.Write($"{done}: {t.Name}");
        return Outcome(t, mode, done, t.Reboot);
    }

    private bool IsAlready(Tweak t, TweakMode mode, object? value, TweakState want)
    {
        if (value is not null && mode == TweakMode.Apply)
        {
            object? current;
            try { current = states.ChoiceValue(t); } catch (Exception) { current = null; }
            return current is not null && RegistryEngine.Matches(current, value);
        }
        if (t.Kind != TweakKind.Action) return states.Of(t) == want;
        // an Action's Detect: already done (e.g. the app is already removed)
        if (!t.Has("Detect") || t.Code is null) return false;
        try { return t.Code.Detect(t, context) == TweakState.Optimized; } catch (Exception) { return false; }
    }

    private void Change(Tweak t, TweakMode mode, object? value)
    {
        if (t.Kind == TweakKind.Choice)
        {
            var v = mode == TweakMode.Revert ? states.DefaultFor(t) : value ?? t.Recommended;
            if (t.Has("Value"))
            {
                // a Choice over many settings: its C# sets the picked value, or puts the Windows default back
                if (mode == TweakMode.Apply) t.Code!.Apply(t, context, v);
                else t.Code!.Revert(t, context, v);
                return;
            }
            var row = t.Registry![0];
            if (v is null) context.Registry.RemoveValue(row.Path, row.Name!);
            else context.Registry.SetValue(row.Path, row.Name!, v, row.Type ?? "DWord");
            return;
        }
        var rows = t.RowsAreCode ? t.Code!.Rows(t, context) : t.Registry;
        if (rows is { Count: > 0 })
        {
            context.Registry.Invoke(rows, mode, context.System.Build);
            // a registry Toggle's After: one more step after the values, both ways
            if (t.Has("After")) t.Code!.After(t, context, mode);
            return;
        }
        if (mode == TweakMode.Apply) t.Code!.Apply(t, context, null);
        else t.Code!.Revert(t, context, null);
    }

    /// <summary>A SafeMode Tweak's Prepare (Invoke-AkariPrepare): null when it went well or there is none, else its Failed Outcome.</summary>
    public Outcome? Prepare(Tweak t, TweakMode mode)
    {
        if (!t.Has("Prepare")) return null;
        Log.Write($"Getting ready for Safe Mode: {t.Name}");
        try
        {
            if (t.Code is null) throw new NotSupportedException(NotNative(t));
            t.Code.Prepare(t, context);
            return null;
        }
        catch (Exception e)
        {
            Log.Write($"Failed: {t.Name}: {e.Message}");
            return Outcome(t, mode, OutcomeKind.Failed, message: e.Message);
        }
    }

    // a block that restarts the PC or sets the next boot to Safe Mode: nothing after it in the same Run would run
    [GeneratedRegex(@"(?im)\bshutdown(\.exe)?\s+(/|-)r\b|\bRestart-Computer\b|\bbcdedit\b[^\r\n]*\bsafeboot\s+(minimal|network)\b")]
    private static partial Regex RestartPattern();

    /// <summary>True when running it restarts the PC (Test-AkariRestarts): Restarts on Apply, or its block does it.</summary>
    public static bool Restarts(Tweak t, TweakMode mode)
    {
        if (t.Restarts && mode == TweakMode.Apply) return true;
        var block = t.Fields.Get(mode == TweakMode.Revert ? "Revert" : "Apply") as PsScriptBlock;
        return block != null && RestartPattern().IsMatch(block.Text);
    }

    /// <summary>
    /// A Run from a plan (Invoke-AkariPlan): one Outcome per item, in this order: the changes now, Explorer's
    /// restart, the Safe Mode Prepares and handoff, else the one change that restarts the PC.
    /// </summary>
    public IReadOnlyList<Outcome> Run(IEnumerable<PlanItem> items, Func<string, Tweak?> find, IProgress<RunProgress>? progress = null)
    {
        var outcomes = new List<Outcome>();
        var now = new List<(PlanItem Item, Tweak? Tweak)>();
        var last = new List<(PlanItem Item, Tweak Tweak)>();
        var safe = new List<(PlanItem Item, Tweak Tweak)>();
        var inSafe = inSafeMode?.Invoke() ?? false;
        foreach (var i in items)
        {
            var t = find(i.Id);
            if (t != null && t.SafeMode && !inSafe && !(t.Kind == TweakKind.Action && i.Mode == TweakMode.Revert) && Requirements.Check(t, context.System) is null
                && (t.Kind == TweakKind.Action || states.Of(t) != (i.Mode == TweakMode.Revert ? TweakState.Default : TweakState.Optimized)))
                safe.Add((i, t));
            else if (t != null && Restarts(t, i.Mode)) last.Add((i, t));
            else now.Add((i, t));
        }
        var total = now.Count + safe.Count + Math.Min(1, last.Count);
        var done = 0;
        var restartExplorer = false;
        foreach (var (i, t) in now)
        {
            progress?.Report(new RunProgress(done, total, t?.Name ?? i.Id));
            done++;
            if (t is null)
            {
                Log.Write($"Failed: {i.Id} (unknown tweak id)");
                outcomes.Add(new Outcome(i.Id, i.Mode, OutcomeKind.Failed, Message: "Unknown tweak id"));
                continue;
            }
            var o = Run(t, i.Mode, i.Value);
            if (t.Explorer && o.Kind is OutcomeKind.Applied or OutcomeKind.Reverted) restartExplorer = true;
            outcomes.Add(o);
        }
        if (restartExplorer)
        {
            progress?.Report(new RunProgress(done, total, "Restarting Explorer"));
            Log.Write("Restarting Explorer");
            explorer.Restart();
        }
        // what the Safe Mode Tweaks need first (normal mode, network up); one whose Prepare failed stays here
        foreach (var x in safe.ToList())
        {
            progress?.Report(new RunProgress(done, total, x.Tweak.Name));
            done++;
            if (Prepare(x.Tweak, x.Item.Mode) is { } failed) { outcomes.Add(failed); safe.Remove(x); }
        }
        if (safe.Count > 0)
        {
            // Safe Mode is the restart: the restarting Tweaks wait for another Run
            foreach (var (i, t) in last)
            {
                Log.Write($"Skipped: {t.Name} (it restarts the PC: select it again after Safe Mode)");
                outcomes.Add(Outcome(t, i.Mode, OutcomeKind.Skipped, message: "restarts the PC: run it after Safe Mode"));
            }
            if (safeMode is null)
            {
                foreach (var (i, t) in safe)
                {
                    Log.Write($"Failed: {t.Name} (needs Safe Mode, which the native app can't go into yet)");
                    outcomes.Add(Outcome(t, i.Mode, OutcomeKind.Failed, message: "needs Safe Mode, which the native app can't go into yet"));
                }
                return outcomes;
            }
            foreach (var (i, t) in safe)
            {
                Log.Write($"In Safe Mode: {t.Name}");
                outcomes.Add(Outcome(t, i.Mode, i.Mode == TweakMode.Revert ? OutcomeKind.Reverted : OutcomeKind.Applied, true, "in Safe Mode, after the restart"));
            }
            progress?.Report(new RunProgress(total, total, "Restarting into Safe Mode"));
            safeMode.Start(safe.Select(x => x.Item).ToList());
            return outcomes;
        }
        // only one can run: once it starts the restart, Windows refuses to start anything else
        for (var n = 0; n < last.Count; n++)
        {
            var (i, t) = last[n];
            if (n == 0)
            {
                progress?.Report(new RunProgress(done, total, t.Name));
                Log.Write($"Last: {t.Name} (restarts the PC)");
                outcomes.Add(Run(t, i.Mode, i.Value));
            }
            else
            {
                Log.Write($"Skipped: {t.Name} (it restarts the PC too: select it again after this restart)");
                outcomes.Add(Outcome(t, i.Mode, OutcomeKind.Skipped, message: "restarts the PC too: run it after this restart"));
            }
        }
        return outcomes;
    }

    /// <summary>A Run with one Mode for every id (the CLI's --apply / --revert).</summary>
    public IReadOnlyList<Outcome> Run(IEnumerable<string> ids, TweakMode mode, Func<string, Tweak?> find, IProgress<RunProgress>? progress = null) =>
        Run(ids.Select(id => new PlanItem(id, mode)), find, progress);
}
