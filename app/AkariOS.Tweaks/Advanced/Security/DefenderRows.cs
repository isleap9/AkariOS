using AkariOS.Core.Data;
using AkariOS.Core.Sources;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.Advanced.Security;

/// <summary>What the two Defender Toggles share: their rows read out of Files/&lt;file&gt;.psd1 (Import-PowerShellDataFile's
/// Registry list) and the write the blocks do: some rows as TrustedInstaller, then every row as admin, a value Windows
/// still guards only logged.</summary>
internal static class DefenderRows
{
    public static IReadOnlyList<RegistryRow> Read(Tweak tweak, TweakContext c, string file)
    {
        var d = PsData.Parse(c.Files.ReadText($"{TweakContext.FolderOf(tweak)}/Files/{file}")).Value as PsHashtable
            ?? throw new InvalidOperationException($"{file} can't be read");
        return PsSemantics.AsList(d.Get("Registry")).OfType<PsHashtable>()
            .Select(h => Loader.ToRow(h) ?? throw new InvalidOperationException($"{file}: a row can't be read")).ToList();
    }

    public static void Write(TweakContext c, IReadOnlyList<RegistryRow> trusted, IReadOnlyList<RegistryRow> rows, TweakMode mode, Func<RegistryRow, string> name)
    {
        c.Registry.Invoke(trusted, mode, c.System.Build, asTrusted: true);
        foreach (var r in rows)
        {
            try { c.Registry.Invoke([r], mode, c.System.Build); }
            catch (Exception e) when (e is UnauthorizedAccessException or System.Security.SecurityException or IOException)
            {
                c.Log.Write($"Kept by Windows: {name(r)} ({e.Message})");
            }
        }
    }
}
