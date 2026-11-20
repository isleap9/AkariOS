using AkariOS.App.Shell;
using AkariOS.Core;
using AkariOS.Core.Runs;
using AkariOS.Core.Tweaks;
using AkariOS.Framework.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.ViewModels;

/// <summary>
/// Remove apps (Apps.ps1's Show-AkariRemoveApps): the Apps step's four Remove lists alone, one at a time, with "n
/// selected" and the accent Remove (n). Remove asks with the names, then removes them in one Run (the session's restore
/// point first); each row goes as the Run gets past it. After the Run the lists are read again. One per app.
/// </summary>
public sealed partial class RemoveAppsViewModel : ObservableObject
{
    private readonly Engine _engine;
    private readonly IBackground _background;
    private readonly IDialogService _dialogs;
    private readonly ShellState _shell;
    private readonly RestoreRule _restore;
    private readonly CatalogueViewModel _catalogue;
    private readonly HomeStats _stats;
    private readonly ActivityLog _activity;
    private readonly AppIcons _icons;
    private readonly OrderedDictionary<string, Pending> _sel = [];

    public RemoveAppsViewModel(Engine engine, IBackground background, IDialogService dialogs, ShellState shell, RestoreRule restore,
        CatalogueViewModel catalogue, HomeStats stats, ActivityLog activity, AppIcons icons)
    {
        (_engine, _background, _dialogs, _shell, _restore, _catalogue, _stats, _activity, _icons) =
            (engine, background, dialogs, shell, restore, catalogue, stats, activity, icons);
        Apps = New();
    }

    [ObservableProperty]
    public partial AppsStepViewModel Apps { get; private set; }

    /// <summary>The Run removes them now.</summary>
    [ObservableProperty]
    public partial bool Running { get; private set; }

    [ObservableProperty]
    public partial string CountText { get; private set; } = "0 selected";

    [ObservableProperty]
    public partial string RemoveText { get; private set; } = "Remove";

    [ObservableProperty]
    public partial bool CanRemove { get; private set; }

    private BusyWork? _busy;

    private AppsStepViewModel New() => new(_engine, _background, _dialogs, _icons, _sel, Update);

    /// <summary>The page was opened: the apps are read (once).</summary>
    public void Shown()
    {
        Apps.Ensure();
        Apps.ShowTab("Remove");
    }

    private void Update()
    {
        var n = _sel.Count;
        CountText = $"{n} selected";
        RemoveText = n > 0 ? $"Remove ({n})" : "Remove";
        CanRemove = n > 0 && !Running;
    }

    /// <summary>Start-AkariRemoveApps: asks with the names, then one Run of the picks after the restore point.</summary>
    [RelayCommand]
    public async Task RemoveAsync(bool skipRestore = false)
    {
        var rows = Apps.PickedRemovals();
        var n = rows.Count;
        if (n == 0 || Running) return;
        if (_shell.IsBusy || _catalogue.Running)
        {
            await _dialogs.ShowInfoAsync("Remove apps", "Changes are still running. Remove these when they are done.");
            return;
        }
        if (!skipRestore)
        {
            var names = string.Join(", ", rows.Take(6).Select(r => r.Name)) + (n > 6 ? $" and {n - 6} more" : "");
            if (!await _dialogs.ConfirmAsync($"Remove {n} app{(n == 1 ? "" : "s")}?",
                    $"{names}.\nStore apps can be reinstalled from the Microsoft Store or Downloads.", "Remove")) return;
        }
        var restore = !skipRestore && await _restore.ChooseAsync("Remove apps");
        var plan = Selection.PlanItems(_sel.Values);
        var label = $"Removing {n} app{(n == 1 ? "" : "s")}";
        Running = true;
        Update();
        _shell.Locked = true;
        _busy = _shell.Begin(label);
        _engine.Log.Write(label);
        // the busy toast counts the apps ("Removing 5 apps (2 of 5): Xbox"), the rows go as the Run passes them
        var progress = new PostedProgress(_background, p =>
        {
            if (_busy is { } b) _shell.Report(b, p);
            Gone(rows, p.Done);
        });
        _background.Run(() =>
        {
            if (restore && _engine.RestorePoints?.Create("AkariOS") is { Ok: false } refused) return refused;
            try { return _engine.Runner.Run(plan, _engine.Find, progress); }
            catch (Exception e) { _engine.Log.WriteFile($"Error: Remove apps: {e}"); return null; }
        }, r => _ = Guard(DoneAsync(r, restore)));
    }

    // Update-AkariRemoveProgress: the rows the Run got past are gone from the lists
    private static void Gone(IReadOnlyList<AppRowViewModel> rows, int done)
    {
        for (var i = 0; i < Math.Min(done, rows.Count); i++) rows[i].Shows = Visibility.Collapsed;
    }

    private async Task DoneAsync(object? r, bool restore)
    {
        Running = false;
        _shell.End(_busy);
        Update();
        if (r is RestoreResult refused)
        {
            // still locked while it asks: the changes waiting elsewhere don't start in between
            if (await _dialogs.ConfirmAsync("Restore point", $"AkariOS could not create a restore point:\n\n{refused.Message}\n\nRemove the apps without a restore point?", "Remove anyway"))
            {
                _restore.Done = true;
                await RemoveAsync(skipRestore: true);
                if (!Running) _shell.Locked = false;
                return;
            }
            _shell.Locked = false;
            return;
        }
        _shell.Locked = false;
        if (restore) _restore.Done = true;
        if (r is not IReadOnlyList<Outcome> outcomes)
        {
            _shell.Toast("Remove apps stopped", "The removal stopped before it ran. The details are in akari.log.", InfoBarSeverity.Error);
            return;
        }
        var ok = outcomes.Count(o => o.Kind is OutcomeKind.Applied or OutcomeKind.Reverted);
        var bad = outcomes.Count(o => o.Kind == OutcomeKind.Failed);
        _activity.Add($"Removed {ok} app{(ok == 1 ? "" : "s")}", "Remove apps", ok, "trash-2");
        // Complete-AkariApply's Remove toast
        _shell.Toast("Removed", $"{ok} app{(ok == 1 ? " is" : "s are")} gone." + (bad > 0 ? $" {bad} failed: see the log." : ""),
            bad > 0 ? InfoBarSeverity.Warning : InfoBarSeverity.Success);
        // what is on this PC changed: the lists are read again, Home's counts too
        _sel.Clear();
        var list = Apps.RemoveList;
        Apps = New();
        Apps.RemoveList = list;
        Shown();
        Update();
        _stats.Stale();
    }

    private async Task Guard(Task task)
    {
        try { await task; }
        catch (Exception e)
        {
            _engine.Log.WriteFile($"Error: UI: {e}");
            if (!Running) _shell.Locked = false;
        }
    }
}
