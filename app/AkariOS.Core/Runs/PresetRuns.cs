using AkariOS.Core.Apps;
using AkariOS.Core.Presets;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Runs;

/// <summary>A preset's Run, every Tweak and Entry it can name, and the ids it names that aren't Tweaks here.</summary>
public sealed record PresetRun(PhaseRun Run, IReadOnlyList<Tweak> Tweaks, IReadOnlyList<string> Unknown);

/// <summary>New-AkariPresetRun: a preset's wildcards (appx/*, capability/*, feature/*) become the Entries on this PC now.</summary>
public static class PresetRuns
{
    public static PresetRun Make(Preset preset, LoadResult loaded, AppPackages? apps, bool revert, string sid)
    {
        var all = loaded.Tweaks.ToList();
        if (apps != null && preset.Entries.Any(e => e.Id.EndsWith("/*", StringComparison.Ordinal)))
        {
            var known = all.Select(t => t.Id).ToHashSet(StringComparer.Ordinal);
            var names = apps.Installed().Select(n => $"appx/{n}")
                .Concat(apps.InstalledCapabilities().Select(n => $"capability/{n}"))
                .Concat(apps.EnabledFeatures().Select(n => $"feature/{n}"));
            foreach (var id in names)
            {
                if (!known.Add(id)) continue;
                if (Loader.ResolveEntry(loaded.Groups, id) is { } e) all.Add(e);
            }
        }
        var plan = PresetStore.Resolve(preset, all, revert);
        var run = new PhaseRun { Name = preset.Name, Sid = sid, Phases = PresetStore.Phases(preset, plan.Items, revert) };
        return new PresetRun(run, all, plan.Unknown);
    }
}
