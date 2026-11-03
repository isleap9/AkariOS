using System.Text.Json;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Core.Tests;

/// <summary>
/// The native Selection against src\UI\Selection.ps1 (Oracle/Export-Selection.ps1) on every real Tweak: the same
/// question before each target (Optimized and Default, or each Choice value and the Default), the same labels.
/// </summary>
public class SelectionOracleTests
{
    private static readonly Lazy<JsonElement> PowerShell = new(() => Oracle.Run("Export-Selection.ps1", "-Src", Repo.Src));

    [Fact]
    public void The_same_questions_and_labels_for_every_tweak()
    {
        var tweaks = new Loader(new FolderSourceFiles(Repo.Root), new Dictionary<string, ITweakCode>()).Load().Tweaks;
        var ps = PowerShell.Value;
        Assert.Equal(ps.EnumerateObject().Select(p => p.Name).Order(), tweaks.Select(t => t.Id).Order());
        var asked = 0;
        foreach (var t in tweaks)
        {
            var expected = ps.GetProperty(t.Id);
            var mine = t.Kind == TweakKind.Choice
                ? t.Choices.Select(c => c.Value).Append(States.DefaultOn(t, 26100)).Select(v => Selection.ConfirmText(t, v, States.DefaultOn(t, 26100)) ?? "")
                : [Selection.ConfirmText(t, Selection.Optimized, null) ?? "", Selection.ConfirmText(t, "Default", null) ?? ""];
            var want = expected.GetProperty("Confirm").EnumerateArray().Select(e => e.GetString()!).ToList();
            Assert.True(want.SequenceEqual(mine), $"{t.Id}: [{string.Join(" | ", want)}] vs [{string.Join(" | ", mine)}]");
            Assert.Equal(expected.GetProperty("Labels").EnumerateArray().Select(e => e.GetString()), t.Choices.Select(c => Selection.ChoiceLabel(t, c.Value)));
            asked += want.Count(w => w.Length > 0);
        }
        // the real files do ask (Confirm texts, Advanced Tweaks)
        Assert.True(asked > 5, $"{asked} questions");
    }
}
