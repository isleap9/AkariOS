using System.Globalization;
using System.Text.RegularExpressions;
using AkariOS.Core.Data;
using AkariOS.Core.Sources;

namespace AkariOS.Core.Tweaks;

/// <summary>A service on this PC (Get-AkariServices): Start = Automatic, AutomaticDelayed, Manual, Disabled (Boot /
/// System as they are); Status = Running, Stopped…</summary>
public sealed record ServiceInfo(string Name, string DisplayName, string Description, string Start, string Status, bool CanStop);

/// <summary>
/// The Services page's rules (the pure parts of src/UI/ServicesPage.ps1 and Core/System.ps1's start type helpers,
/// Oracle-tested): startup types, filters, the services Windows needs, the Windows defaults and FR33THY's / ZOICWARE's
/// picks from services.psd1, the view, the row's button and the question before a change.
/// </summary>
public static partial class ServiceLists
{
    /// <summary>$AkariStartTypes: the startup types a row offers, with their labels.</summary>
    public static IReadOnlyList<KeyValuePair<string, string>> StartTypes { get; } =
    [
        new("Automatic", "Automatic"), new("AutomaticDelayed", "Automatic (delayed start)"), new("Manual", "Manual"), new("Disabled", "Disabled"),
    ];

    public static bool IsStartType(string s) => StartTypes.Any(p => p.Key == s);

    /// <summary>$AkariServiceFilters (Changed shows as "Not default").</summary>
    public static IReadOnlyList<string> Filters { get; } = ["All", "Running", "Automatic", "Manual", "Disabled", "Changed"];

    /// <summary>$AkariCriticalServices: Windows needs them to start, sign in, show the desktop or play sound.</summary>
    public static IReadOnlyList<string> Critical { get; } =
    [
        "RpcSs", "RpcEptMapper", "DcomLaunch", "LSM", "Power", "PlugPlay", "BrokerInfrastructure", "SamSs",
        "ProfSvc", "Schedule", "CoreMessagingRegistrar", "SystemEventsBroker", "gpsvc", "StateRepository", "Winmgmt", "UserManager",
        "EventLog", "AudioEndpointBuilder", "Audiosrv", "TextInputManagementService", "Dhcp", "Dnscache", "nsi", "AppXSvc", "CryptSvc",
    ];

    /// <summary>$AkariServiceDefaultsPath: services.psd1 (advanced-services-off's start types).</summary>
    public const string DataPath = "src/Tweaks/Advanced/Services/Files/services.psd1";

    /// <summary>ConvertTo-AkariStartType: Win32_Service's StartMode and DelayedAutoStart as a startup type.</summary>
    public static string StartType(string mode, bool delayed) => mode switch
    {
        "Auto" => delayed ? "AutomaticDelayed" : "Automatic",
        "Manual" => "Manual",
        "Disabled" => "Disabled",
        _ => mode,
    };

    /// <summary>ConvertFrom-AkariStartType: the registry Start value (2 automatic, 3 manual, 4 disabled) and
    /// DelayedAutostart of a startup type.</summary>
    public static (int Start, int Delayed) StartValue(string startType) => startType switch
    {
        "Automatic" => (2, 0),
        "AutomaticDelayed" => (2, 1),
        "Manual" => (3, 0),
        "Disabled" => (4, 0),
        _ => throw new ArgumentException($"unknown startup type: {startType}", nameof(startType)),
    };

    /// <summary>Get-AkariStartLabel: a Start value's name.</summary>
    public static string StartLabel(int start) => start switch { 2 => "Automatic", 3 => "Manual", 4 => "Disabled", _ => start.ToString(CultureInfo.InvariantCulture) };

    [GeneratedRegex("^(.+)_[0-9a-f]{4,8}$", RegexOptions.IgnoreCase)]
    private static partial Regex InstanceName();

    /// <summary>Get-AkariServiceTemplate: a per-user instance's template (cbdhsvc_4f2a1 → cbdhsvc), or "".</summary>
    public static string Template(string name) => InstanceName().Match(name) is { Success: true } m ? m.Groups[1].Value : "";

    private static PsHashtable Data(ISourceFiles files) =>
        files.Exists(DataPath) ? PsData.Parse(files.ReadText(DataPath)).Value as PsHashtable ?? new PsHashtable() : new PsHashtable();

    private static IEnumerable<PsHashtable> Rows(PsHashtable d) => PsSemantics.AsList(d.Get("Services")).OfType<PsHashtable>();

    private static int Int(object? v) => Convert.ToInt32(v, CultureInfo.InvariantCulture);

    /// <summary>Get-AkariServiceDefaults: name → the Windows default Start value.</summary>
    public static IReadOnlyDictionary<string, int> Defaults(ISourceFiles files)
    {
        var d = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        foreach (var s in Rows(Data(files))) d[PsSemantics.Text(s.Get("Name"))!] = Int(s.Get("Default"));
        return d;
    }

    /// <summary>Get-AkariServiceSuggestions: name → what FR33THY's and ZOICWARE's picks set it to.</summary>
    public static IReadOnlyDictionary<string, IReadOnlyList<string>> Suggestions(ISourceFiles files)
    {
        var d = Data(files);
        var out_ = new Dictionary<string, List<string>>(StringComparer.OrdinalIgnoreCase);
        void Add(string n, string text) { if (!out_.TryGetValue(n, out var l)) out_[n] = l = []; l.Add(text); }
        foreach (var s in Rows(d)) if (s.Get("Off") is { } off) Add(PsSemantics.Text(s.Get("Name"))!, $"Off (FR33THY): {StartLabel(Int(off))}");
        foreach (var n in PsSemantics.AsList(d.Get("Light"))) Add(PsSemantics.Text(n)!, "Light (ZOICWARE): Disabled");
        foreach (var n in PsSemantics.AsList(d.Get("Manual"))) Add(PsSemantics.Text(n)!, "Manual (ZOICWARE): Manual");
        return out_.ToDictionary(p => p.Key, p => (IReadOnlyList<string>)p.Value, StringComparer.OrdinalIgnoreCase);
    }

    /// <summary>Get-AkariServiceDefault: its Windows default (a per-user instance: its template's), or null.</summary>
    public static int? Default(ServiceInfo s, IReadOnlyDictionary<string, int> defaults)
    {
        if (defaults.TryGetValue(s.Name, out var d)) return d;
        var tpl = Template(s.Name);
        return tpl.Length > 0 && defaults.TryGetValue(tpl, out d) ? d : null;
    }

    /// <summary>Get-AkariServiceSuggestion: its picks (a per-user instance: its template's), empty when none.</summary>
    public static IReadOnlyList<string> Suggestion(ServiceInfo s, IReadOnlyDictionary<string, IReadOnlyList<string>> suggest)
    {
        if (suggest.TryGetValue(s.Name, out var l)) return l;
        var tpl = Template(s.Name);
        return tpl.Length > 0 && suggest.TryGetValue(tpl, out l) ? l : [];
    }

    /// <summary>Test-AkariServiceChanged: its startup type isn't its known Windows default (delayed = automatic).</summary>
    public static bool Changed(ServiceInfo s, IReadOnlyDictionary<string, int> defaults) =>
        Default(s, defaults) is { } def && IsStartType(s.Start) && StartValue(s.Start).Start != def;

    // Sort-Object DisplayName: the culture's order, case ignored
    private static readonly StringComparer ByName = StringComparer.Create(CultureInfo.CurrentCulture, ignoreCase: true);

    /// <summary>Get-AkariServiceView: the services the filter and the search (name, display name, description) leave,
    /// by display name; with suggest, only the ones FR33THY or ZOICWARE change (null = every service).</summary>
    public static IReadOnlyList<ServiceInfo> View(IEnumerable<ServiceInfo> services, string filter, string query, IReadOnlyDictionary<string, int> defaults,
        IReadOnlyDictionary<string, IReadOnlyList<string>>? suggest)
    {
        var q = query.Trim();
        return services.Where(s =>
        {
            if (suggest is not null && Suggestion(s, suggest).Count == 0) return false;
            var hit = filter switch
            {
                "Running" => s.Status == "Running",
                "Automatic" => s.Start is "Automatic" or "AutomaticDelayed",
                "Manual" => s.Start == "Manual",
                "Disabled" => s.Start == "Disabled",
                "Changed" => Changed(s, defaults),
                _ => true,
            };
            return hit && (q.Length == 0 || $"{s.DisplayName} {s.Name} {s.Description}".Contains(q, StringComparison.OrdinalIgnoreCase));
        }).OrderBy(s => s.DisplayName, ByName).ToList();
    }

    /// <summary>Get-AkariServiceAction: Stop (running and it accepts a stop), Start (stopped, not disabled) or "".</summary>
    public static string Action(ServiceInfo s)
    {
        if (s.Status == "Running") return s.CanStop ? "Stop" : "";
        return s.Status == "Stopped" && s.Start != "Disabled" ? "Start" : "";
    }

    /// <summary>Get-AkariServiceConfirm: the question before disabling or stopping a service Windows needs, or "".
    /// op: StartType (value = a startup type) or Control (value = Start / Stop).</summary>
    public static string Confirm(ServiceInfo s, string op, string value)
    {
        if (!Critical.Contains(s.Name) && !Critical.Contains(Template(s.Name))) return "";
        if (op == "StartType" && value == "Disabled")
            return $"{s.DisplayName} is a service Windows needs. Disabled, Windows may not start, sign you in or work properly until you set it back (in Safe Mode if it no longer starts). Disable it anyway?";
        if (op == "Control" && value == "Stop")
            return $"{s.DisplayName} is a service Windows needs. Stopping it can freeze or close parts of Windows until it starts again or you restart. Stop it anyway?";
        return "";
    }
}
