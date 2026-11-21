using CommunityToolkit.Mvvm.Input;

namespace AkariOS.App.Shell;

/// <summary>A Category's row on its Section's page (Windows 11 Settings' look): its group ("" = the Section's only
/// one, no heading) and a line saying what is inside.</summary>
public sealed record CategoryNote(string Group, string Description);

/// <summary>
/// The lines under each Category on a Section's page, and the groups they sit in, per Section (presentation only, like
/// <see cref="CategoryGlyphs"/>; the Categories themselves come from the loaded Tweaks). A Category missing here goes
/// in the last group, <see cref="More"/>, its line made from its first Tweaks' names (<see cref="FromNames"/>).
/// </summary>
public static class CategoryInfo
{
    public const string More = "More";

    /// <summary>Every Section's Categories, in the order they show on its page.</summary>
    public static IReadOnlyList<(string Section, string Category, CategoryNote Note)> All { get; } =
    [
        ("Optimize", "Gaming", new("Speed", "Game Mode, Game DVR and Game Bar, GPU scheduling, windowed games")),
        ("Optimize", "Performance", new("Speed", "Background apps, visual effects, timer resolution, memory compression, temporary files")),
        ("Optimize", "Power", new("Speed", "Ultimate Performance plan, hibernate and fast startup, device power saving, sleep")),
        ("Optimize", "Network", new("Speed", "DNS server, IPv6, network throttling, vendor download servers")),
        ("Optimize", "Privacy", new("Windows", "Ads and suggestions, Copilot and AI, activity history, app permissions, location")),
        ("Optimize", "Update", new("Windows", "Pause or defer updates, no driver updates, Store app updates, stay on this version")),

        ("Customize", "Taskbar", new("Desktop", "Alignment, the Search, Widgets and Copilot buttons, tray icons, Quick Settings")),
        ("Customize", "Start", new("Desktop", "AkariOS pins, Recommended, All apps, recent files and suggestions")),
        ("Customize", "Explorer", new("Desktop", "Classic right-click menu, file extensions, hidden files, the navigation pane")),
        ("Customize", "Context menu", new("Desktop", "Right-click entries to add or remove: Take Ownership, Run as administrator, Print, Cast")),
        ("Customize", "Theme", new("Desktop", "Dark mode, the AkariOS wallpaper, lock and sign-in screens, transparency")),
        ("Customize", "System", new("Behaviour", "Alt+Tab, consoles, snapping, shut down, display scaling, the clock")),
        ("Customize", "Notifications", new("Behaviour", "Do not disturb, the notification center, Windows' own notifications")),
        ("Customize", "Input", new("Behaviour", "Mouse pointers and precision, key repeat, touch keyboard, autocorrect")),
        ("Customize", "Sound", new("Behaviour", "Call ducking, loudness equalization, Windows and startup sounds")),
        ("Customize", "Accessibility", new("Behaviour", "Filter Keys, Narrator, scroll bars, accessibility shortcuts")),
        ("Customize", "Apps", new("Behaviour", "Edge, Brave, Notepad, Photos, Microsoft Store, Windows Terminal, Outlook")),

        ("Hardware", "Graphics", new("", "NVIDIA, AMD and Intel settings, MSI mode, full GPU clocks, Resizable BAR")),
        ("Hardware", "Input", new("", "Mouse polling in background windows")),

        ("Advanced", "System", new("System", "Prefetch, reserved storage, the NVMe driver, the Start and Search hosts")),
        ("Advanced", "Services", new("System", "Every Windows service's startup type, or most of them off at once")),
        ("Advanced", "Scheduled tasks", new("System", "Every scheduled task on or off, or all of them removed")),
        ("Advanced", "Tuning", new("System", "Processor scheduling and the service host split")),
        ("Advanced", "Display", new("System", "Flip models and multiplane overlay")),
        ("Advanced", "Security", new("Security and features", "Microsoft Defender, the firewall, SmartScreen, Spectre and Meltdown, core isolation")),
        ("Advanced", "Features", new("Security and features", ".NET 3.5, Hyper-V, Sandbox, WSL, OpenSSH Server, F8 recovery")),

        ("Tools", "Setup", new("Keep it running", "A restore point, activation, Home to Pro, updating every app")),
        ("Tools", "Drivers", new("Keep it running", "The latest NVIDIA, AMD and Intel drivers, a DDU clean, Snappy Driver Installer, controller overclock")),
        ("Tools", "Cleanup", new("Keep it running", "Temporary files, Windows.old, logs, old drivers, startup entries")),
        ("Tools", "Fixes", new("Keep it running", "Windows Update reset, network reset, corruption scan, WinGet reinstall")),
        ("Tools", "Check", new("Check and recover", "BIOS, storage, RAM, GPU and polling rate tests, O&O ShutUp10++")),
        ("Tools", "Refresh", new("Check and recover", "Reinstall Windows, factory reset, Gaming Services repair, restart to BIOS")),
        ("Tools", "Panels", new("Check and recover", "Control Panel, Network Connections, Power Options and the other classic panels")),
    ];

    private static int IndexOf(string section, string category)
    {
        for (var i = 0; i < All.Count; i++)
            if (string.Equals(All[i].Section, section, StringComparison.OrdinalIgnoreCase)
                && string.Equals(All[i].Category, category, StringComparison.OrdinalIgnoreCase)) return i;
        return -1;
    }

    public static CategoryNote? Of(string section, string category) => IndexOf(section, category) is var i and >= 0 ? All[i].Note : null;

    /// <summary>The order of a Category in <see cref="All"/>; one not listed goes last.</summary>
    public static int Order(string section, string category) => IndexOf(section, category) is var i and >= 0 ? i : int.MaxValue;

    /// <summary>A line for a Category not listed: its first three Tweaks' names, "…" when it has more.</summary>
    public static string FromNames(IReadOnlyList<string> names) =>
        string.Join(", ", names.Take(3)) + (names.Count > 3 ? ", …" : "");
}

/// <summary>A link in a page's crumb line (above its heading): its text and where it goes.</summary>
public sealed class CrumbLink(string text, Action open)
{
    public string Text { get; } = text;
    public IRelayCommand OpenCommand { get; } = new RelayCommand(open);
}
