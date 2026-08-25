using System.Diagnostics;
using System.Net.NetworkInformation;
using Microsoft.Extensions.Logging;

namespace AkariOS.App.Services;

/// <summary>Result of one playbook requirement check.</summary>
public sealed record RequirementCheck(
    string Id,
    string Title,
    string Description,
    bool IsMet,
    bool CanAutoFix,
    string? Details = null);

/// <summary>
/// Evaluates the playbook's declared requirements (from playbook.conf) against this system.
/// Mirrors the checks the AME CLI performs before running, so the UI can resolve them
/// comfortably instead of the CLI blocking on Console.ReadKey().
/// </summary>
public sealed partial class RequirementsService
{
    private readonly ILogger<RequirementsService>? logger;

    public RequirementsService(ILogger<RequirementsService>? logger = null)
    {
        this.logger = logger;
    }

    /// <summary>Runs every check we know how to evaluate. Unknown requirements are ignored.</summary>
    public IReadOnlyList<RequirementCheck> Evaluate(IReadOnlyList<string> required)
    {
        var results = new List<RequirementCheck>();
        foreach (var req in required)
        {
            switch (req)
            {
                case "Internet":
                    results.Add(CheckInternet());
                    break;
                case "NoAntivirus":
                    results.Add(CheckThirdPartyAntivirus());
                    break;
                case "PluggedIn":
                    results.Add(CheckPowerSource());
                    break;
                case "DefenderToggled":
                    results.Add(CheckDefenderToggles());
                    break;
                case "UCPDDisabled":
                    results.Add(CheckUcpd());
                    break;
                default:
                    logger?.LogInformation("Unknown requirement '{Req}' — skipped", req);
                    break;
            }
        }
        return results;
    }

    // ----- individual checks -----

    private static RequirementCheck CheckInternet() =>
        NetworkInterface.GetIsNetworkAvailable()
            ? new("internet", "Internet", "An internet connection is required to fetch packages during setup.", true, false)
            : new("internet", "Internet", "Connect to the internet before continuing.", false, false);

    private static RequirementCheck CheckThirdPartyAntivirus()
    {
        // SecurityCenter2 exposes registered AV products; anything besides Defender counts.
        try
        {
            using var searcher = new System.Management.ManagementObjectSearcher(
                @"root\SecurityCenter2", "SELECT displayName FROM AntiVirusProduct");
            var third = searcher.Get().Cast<System.Management.ManagementObject>()
                .Select(o => (o["displayName"] as string ?? "").Trim())
                .Where(n => n.Length > 0 && !n.Contains("Windows Defender", StringComparison.OrdinalIgnoreCase)
                            && !n.Contains("Microsoft Defender", StringComparison.OrdinalIgnoreCase))
                .ToList();

            return third.Count == 0
                ? new("noav", "Third-party antivirus", "No conflicting antivirus detected.", true, false)
                : new("noav", "Third-party antivirus",
                      $"Uninstall or disable: {string.Join(", ", third)}.", false, false);
        }
        catch (Exception ex)
        {
            return new("noav", "Third-party antivirus", $"Could not verify ({ex.Message}).", false, false);
        }
    }

    private static RequirementCheck CheckPowerSource()
    {
        try
        {
            using var ps = new System.Management.ManagementObjectSearcher(
                @"root\WMI", "SELECT BatteryStatus FROM BatteryStatus");
            var onBattery = ps.Get().Cast<System.Management.ManagementObject>().Any();
            return onBattery
                ? new("power", "Power source", "Plug the device into AC power before continuing.", false, false)
                : new("power", "Power source", "Device is running on AC power.", true, false);
        }
        catch
        {
            // Desktops have no battery class at all → treat as plugged in.
            return new("power", "Power source", "Device is running on AC power.", true, false);
        }
    }

    private static RequirementCheck CheckDefenderToggles()
    {
        // Exact same logic as the AME CLI's GetDefenderToggles (CLI.cs:389) — the playbook
        // will only run when all four return "off". Checks policy key first, falls back to
        // the Defender key, matching what the toggles actually write.
        var toggles = GetDefenderToggles();
        var offCount = toggles.Count(t => !t);
        var allOff = toggles.All(t => !t);

        return allOff
            ? new("defender", "Windows Defender", $"All 4 toggles are off ({string.Join(", ", toggles.Select((t, i) => $"#{i + 1}:{(t ? "on" : "off")}"))}).", true, true)
            : new("defender", "Windows Defender",
                  $"Turn off all 4 toggles in Windows Security — {offCount}/4 currently off.",
                  false, true);
    }

    /// <summary>
    /// Port of AME CLI GetDefenderToggles: [realtime, spynet-reporting, spynet-consent, tamper].
    /// true = toggle is ON (protection active), false = OFF.
    /// </summary>
    private static List<bool> GetDefenderToggles()
    {
        var result = new List<bool>();

        using var defenderKey = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Windows Defender");
        using var policiesKey = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Policies\Microsoft\Windows Defender");

        // 1) Real-time protection
        try
        {
            using var realtimePolicy = policiesKey?.OpenSubKey("Real-Time Protection");
            using var realtimeKey = realtimePolicy ?? defenderKey?.OpenSubKey("Real-Time Protection");
            if (realtimeKey is null)
                result.Add(false);
            else
                result.Add((int?)realtimeKey.GetValue("DisableRealtimeMonitoring") != 1);
        }
        catch
        {
            result.Add(false);
        }

        // 2+3) SpyNet (cloud reporting + sample consent)
        try
        {
            using var spynetPolicy = policiesKey?.OpenSubKey("SpyNet");
            using var spynetKey = spynetPolicy ?? defenderKey?.OpenSubKey("SpyNet");

            int reporting = 0, consent = 0;
            if (spynetKey is not null)
            {
                reporting = (int?)spynetKey.GetValue("SpyNetReporting") ?? 0;
                consent = (int?)spynetKey.GetValue("SubmitSamplesConsent") ?? 0;
            }
            if (reporting == 0 && spynetPolicy != null)
                reporting = (int?)defenderKey?.OpenSubKey("SpyNet")?.GetValue("SpyNetReporting") ?? 0;

            result.Add(reporting != 0);
            result.Add(consent != 0 && consent != 2 && consent != 4);
        }
        catch
        {
            result.Add(false);
            result.Add(false);
        }

        // 4) Tamper protection
        try
        {
            var tamper = (int)defenderKey!.OpenSubKey("Features")!.GetValue("TamperProtection")!;
            result.Add(tamper != 4 && tamper != 0);
        }
        catch
        {
            result.Add(false);
        }

        return result;
    }

    private static RequirementCheck CheckUcpd()
    {
        const string serviceName = "UCPD";
        try
        {
            using var svc = new System.ServiceProcess.ServiceController(serviceName);
            var stopped = svc.Status is System.ServiceProcess.ServiceControllerStatus.Stopped
                or System.ServiceProcess.ServiceControllerStatus.StopPending;
            return stopped
                ? new("ucpd", "User Choice Protection Driver (UCPD)", "The UCPD driver is disabled.", true, true)
                : new("ucpd", "User Choice Protection Driver (UCPD)",
                      "Must be disabled to enable custom shell and default browser changes.", false, true);
        }
        catch (Exception ex)
        {
            // Service missing entirely = nothing to disable = met.
            return new("ucpd", "User Choice Protection Driver (UCPD)", "UCPD driver not present.", true, true);
        }
    }

    /// <summary>
    /// One-click fixes. UCPD needs an elevated service stop; Defender just opens
    /// Windows Security (unelevated) for the user to flip the toggles manually.
    /// Returns false when the user declines UAC or the action fails.
    /// </summary>
    public static bool TryAutoFix(string id)
    {
        try
        {
            // Defender: simply open the right settings page — no elevation, no scripts.
            if (id == "defender")
            {
                using var p = Process.Start(new ProcessStartInfo
                {
                    FileName = "windowsdefender://protection",
                    UseShellExecute = true,
                });
                return p != null;
            }

            var script = id switch
            {
                // Stop + disable UCPD driver service (needs elevation).
                "ucpd" => "sc stop UCPD; sc config UCPD start= disabled",
                _ => null,
            };
            if (script is null) return false;

            var psi = new ProcessStartInfo
            {
                FileName = "powershell.exe",
                Arguments = $"-NoProfile -ExecutionPolicy Bypass -Command \"{script}\"",
                UseShellExecute = true,
                Verb = "runas",
                CreateNoWindow = true,
            };
            using var p2 = Process.Start(psi);
            return p2 != null;
        }
        catch (System.ComponentModel.Win32Exception ex) when (ex.NativeErrorCode == 1223)
        {
            return false; // UAC declined
        }
    }
}
