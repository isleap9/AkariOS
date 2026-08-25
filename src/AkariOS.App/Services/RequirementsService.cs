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
        // The AME CLI requires all 4 Windows Security toggles OFF. Those toggles persist as
        // registry values under Windows Defender Security Center policies; MsMpEng keeps
        // RUNNING even when they're all off, so process presence is NOT a valid signal.
        var (allOff, detail) = GetDefenderToggleState();
        return allOff
            ? new("defender", "Windows Defender", "All Windows Security toggles are off.", true, true)
            : new("defender", "Windows Defender",
                  "Turn off all 4 toggles in Windows Security (real-time, cloud, sample submission, tamper).",
                  false, true);
    }

    /// <summary>Reads the 4 Defender toggle states from policy/registry. True = all off.</summary>
    private static (bool AllOff, string Detail) GetDefenderToggleState()
    {
        const string keyPath = @"SOFTWARE\Microsoft\Windows Defender Security Center\Real-time security";
        var names = new[]
        {
            "DisableRealtimeMonitoring",          // Virus & threat protection settings
            "DisableBehaviorMonitoring",
            "DisableIOAVProtection",
            "DisableScriptScanning",
        };

        var off = 0;
        try
        {
            using var base1 = Microsoft.Win32.Registry.LocalMachine.OpenSubKey(keyPath);
            if (base1 is null)
                return (false, "registry key missing");

            foreach (var name in names)
            {
                var v = base1.GetValue(name);
                // Value present and = 1 means that toggle was switched OFF by the user.
                if (v is int i && i == 1) off++;
            }
            return (off >= 4, $"{off}/4 toggles off");
        }
        catch
        {
            return (false, "could not read toggle state");
        }
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
