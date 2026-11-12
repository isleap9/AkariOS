using AkariOS.Core.Data;
using AkariOS.Core.Tweaks;

namespace AkariOS.Tweaks.OneClick.Finish;

/// <summary>src/Tweaks/OneClick/Finish/Registry.ps1: src/OneClick/reg.reg, the AkariOS settings file, read with
/// RegReader and written through the registry engine in the file's order (the PowerShell app imports it with reg.exe):
/// HKEY_CURRENT_USER is the real user's, a [-key] deletes it with its contents, "name"=- deletes a value. A value
/// Windows refuses is logged and the rest still written; the Action then fails, as reg.exe's import does. An Action: a
/// whole settings file, no single Default.</summary>
[TweakCode("oneclick-registry")]
public sealed class ImportRegFile : ITweakCode
{
    public const string File = "src/OneClick/reg.reg";

    public void Apply(Tweak tweak, TweakContext c, object? value)
    {
        var failed = 0;
        void Try(string what, Action write)
        {
            try { write(); }
            catch (Exception e) when (e is UnauthorizedAccessException or System.Security.SecurityException or IOException or ArgumentException)
            {
                failed++;
                c.Log.Write($"Kept by Windows: {what} ({e.Message})");
            }
        }
        foreach (var key in RegReader.Parse(RegReader.Decode(c.Files.ReadBytes(File))).Keys)
        {
            var path = RegReader.ToTweakPath(key.Path);
            if (key.Delete) { Try(path, () => c.Registry.DeleteKey(path)); continue; }
            Try(path, () => c.Registry.CreateKey(path));
            foreach (var v in key.Values)
            {
                if (v.Delete) Try($@"{path}\{v.Name}", () => c.Registry.RemoveValue(path, v.Name));
                else Try($@"{path}\{v.Name}", () => c.Registry.SetValue(path, v.Name, v.Data, v.Kind.ToString()));
            }
        }
        if (failed > 0) throw new InvalidOperationException($"reg.reg: {failed} value{(failed == 1 ? "" : "s")} could not be written (see the log)");
    }
}
