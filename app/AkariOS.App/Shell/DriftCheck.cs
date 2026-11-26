using AkariOS.App.ViewModels;
using AkariOS.Core;
using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;
using AkariOS.Framework.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Shell;

/// <summary>
/// The drift check (About.ps1's Start- / Complete-AkariDriftCheck, plan 2026-11-26-new-features.md X3): the settings in
/// expected.json that are no longer what AkariOS set. On launch only when Windows' build or update revision changed
/// since the last check (settings <c>Drift.Build</c>) and something was recorded; from Settings › Recovery › Check my
/// setup at any time. Found = Home's InfoBar and a toast; <see cref="Review"/> opens Guided's Tweaks step with them
/// picked.
/// </summary>
public sealed partial class DriftCheck(Engine engine, IBackground background, ShellState shell, ISettingsService settings,
    InstallViewModel install, IShellNavigator navigator) : ObservableObject
{
    public const string BuildKey = "Drift.Build";

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(Found), nameof(Title))]
    public partial IReadOnlyList<DriftItem> Items { get; private set; } = [];

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(Found))]
    public partial bool Dismissed { get; set; }

    [ObservableProperty] public partial bool Checking { get; private set; }

    /// <summary>Home's InfoBar is open.</summary>
    public bool Found => Items.Count > 0 && !Dismissed;

    public string Title => $"{Items.Count} AkariOS setting{(Items.Count == 1 ? "" : "s")} went back to Windows' values";

    public const string Message = "Windows changed them back, most likely with an update. Review them and apply them again.";

    /// <summary>Get-AkariBuildRevision: CurrentBuild.UBR (a Windows update changes it).</summary>
    public string BuildRevision()
    {
        const string nt = @"HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion";
        return $"{PsSemantics.Text(engine.Registry.GetValue(nt, "CurrentBuild"))}.{PsSemantics.Text(engine.Registry.GetValue(nt, "UBR"))}";
    }

    /// <summary>Start-AkariDriftCheck: manual = Settings' card (always, busy toast, the result told); else the launch
    /// check (only after a build change, quiet unless something went back).</summary>
    public async Task CheckAsync(bool manual)
    {
        if (Checking || engine.Expected is not { } store) return;
        var build = BuildRevision();
        if (!manual && (store.All().Count == 0 || await settings.GetAsync<string>(BuildKey, "") == build)) return;
        Checking = true;
        var busy = manual ? shell.Begin("Checking your setup") : null;
        var done = new TaskCompletionSource<object?>();
        background.Run(() =>
        {
            var expected = store.All();
            return (Drift.Find(engine.Loaded.Tweaks, expected, engine.States, engine.System), expected.Count);
        }, r => done.SetResult(r));
        var (items, count) = await done.Task is ValueTuple<IReadOnlyList<DriftItem>, int> t ? t : ([], 0);
        if (busy is not null) shell.End(busy);
        Checking = false;
        Items = items;
        Dismissed = false;
        await settings.SetAsync(BuildKey, build);
        engine.Log.Write($"Setup check: {items.Count} of {count} AkariOS settings went back");
        if (manual)
        {
            if (items.Count > 0) Review();
            else shell.Toast("Your setup is as AkariOS left it",
                count > 0 ? $"All {count} settings AkariOS changed are still set." : "AkariOS has not changed any settings on this PC yet.",
                InfoBarSeverity.Success);
            return;
        }
        if (items.Count > 0)
            shell.Toast($"{items.Count} setting{(items.Count == 1 ? "" : "s")} went back", "Windows changed them back, most likely with an update.",
                InfoBarSeverity.Warning, "Review", Review);
    }

    /// <summary>Open-AkariDriftReview: Guided's Tweaks step with the drifted settings picked.</summary>
    public void Review()
    {
        if (Items.Count == 0 || install.Running) return;
        install.GuideTweaks(Drift.ToPreset(Items));
        navigator.Open("Install AkariOS");
    }
}
