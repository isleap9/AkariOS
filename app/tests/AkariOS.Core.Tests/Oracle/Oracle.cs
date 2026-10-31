using System.Diagnostics;
using System.Text.Json;

namespace AkariOS.Core.Tests;

/// <summary>
/// Runs one of the Oracle/*.ps1 scripts: the PowerShell app's own code reading the shared files, as the reference
/// the native readers are compared with. The scripts only read files; nothing they load is run.
/// </summary>
internal static class Oracle
{
    /// <summary>Runs Oracle/&lt;script&gt; with -Out &lt;a temp file&gt; and the given arguments, and returns its JSON.</summary>
    public static JsonElement Run(string script, params string[] args)
    {
        var out_ = Path.Combine(Path.GetTempPath(), $"akari-oracle-{Guid.NewGuid():N}.json");
        var psi = new ProcessStartInfo("powershell.exe")
        {
            RedirectStandardError = true,
            RedirectStandardOutput = true,
            UseShellExecute = false,
        };
        foreach (var a in new[] { "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File",
                     Path.Combine(Repo.Root, "app", "tests", "AkariOS.Core.Tests", "Oracle", script) }.Concat(args).Concat(["-Out", out_]))
            psi.ArgumentList.Add(a);
        using var p = Process.Start(psi)!;
        var stderr = p.StandardError.ReadToEndAsync();
        var stdout = p.StandardOutput.ReadToEndAsync();
        if (!p.WaitForExit(TimeSpan.FromMinutes(5))) { p.Kill(); throw new TimeoutException($"{script} took over 5 minutes"); }
        if (p.ExitCode != 0 || !File.Exists(out_)) throw new InvalidOperationException($"{script} failed ({p.ExitCode}): {stderr.Result}{stdout.Result}");
        try { return JsonDocument.Parse(File.ReadAllText(out_)).RootElement.Clone(); }
        finally { File.Delete(out_); }
    }
}
