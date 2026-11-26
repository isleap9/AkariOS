# Optimize's Section pages: each Category's row (the native app's drill-down, Windows 11 Settings' look): its group
# ('' = the Section's only group, no heading) and a line saying what is inside, in the order the rows show. Shared:
# UI\CataloguePage.ps1 and the native app (Shell/CategoryInfo) read it. A Category missing here goes under "More"
# with its first Tweaks' names, and a test in each app fails: give a new Category its row. ASCII only.
@{
    Categories = @(
        # Optimize
        @{ Section = 'Optimize'; Category = 'Gaming'; Group = 'Speed'; Line = 'Game Mode, Game DVR and Game Bar, GPU scheduling, windowed games' }
        @{ Section = 'Optimize'; Category = 'Performance'; Group = 'Speed'; Line = 'Background apps, visual effects, timer resolution, memory compression, temporary files' }
        @{ Section = 'Optimize'; Category = 'Power'; Group = 'Speed'; Line = 'Ultimate Performance plan, hibernate and fast startup, device power saving, sleep' }
        @{ Section = 'Optimize'; Category = 'Network'; Group = 'Speed'; Line = 'DNS server, IPv6, network throttling, vendor download servers' }
        @{ Section = 'Optimize'; Category = 'Privacy'; Group = 'Windows'; Line = 'Ads and suggestions, Copilot and AI, activity history, app permissions, location' }
        @{ Section = 'Optimize'; Category = 'Update'; Group = 'Windows'; Line = 'Pause or defer updates, no driver updates, Store app updates, stay on this version' }

        # Customize
        @{ Section = 'Customize'; Category = 'Taskbar'; Group = 'Desktop'; Line = 'Alignment, the Search, Widgets and Copilot buttons, tray icons, Quick Settings' }
        @{ Section = 'Customize'; Category = 'Start'; Group = 'Desktop'; Line = 'AkariOS pins, Recommended, All apps, recent files and suggestions' }
        @{ Section = 'Customize'; Category = 'Explorer'; Group = 'Desktop'; Line = 'Classic right-click menu, file extensions, hidden files, the navigation pane' }
        @{ Section = 'Customize'; Category = 'Context menu'; Group = 'Desktop'; Line = 'Right-click entries to add or remove: Take Ownership, Run as administrator, Print, Cast' }
        @{ Section = 'Customize'; Category = 'Theme'; Group = 'Desktop'; Line = 'Dark mode, the AkariOS wallpaper, lock and sign-in screens, transparency' }
        @{ Section = 'Customize'; Category = 'System'; Group = 'Behaviour'; Line = 'Alt+Tab, consoles, snapping, shut down, display scaling, the clock' }
        @{ Section = 'Customize'; Category = 'Notifications'; Group = 'Behaviour'; Line = 'Do not disturb, the notification center, Windows'' own notifications' }
        @{ Section = 'Customize'; Category = 'Input'; Group = 'Behaviour'; Line = 'Mouse pointers and precision, key repeat, touch keyboard, autocorrect' }
        @{ Section = 'Customize'; Category = 'Sound'; Group = 'Behaviour'; Line = 'Call ducking, loudness equalization, Windows and startup sounds' }
        @{ Section = 'Customize'; Category = 'Accessibility'; Group = 'Behaviour'; Line = 'Filter Keys, Narrator, scroll bars, accessibility shortcuts' }
        @{ Section = 'Customize'; Category = 'Apps'; Group = 'Behaviour'; Line = 'Edge, Brave, Notepad, Photos, Microsoft Store, Windows Terminal, Outlook' }

        # Hardware
        @{ Section = 'Hardware'; Category = 'Graphics'; Group = ''; Line = 'NVIDIA, AMD and Intel settings, MSI mode, full GPU clocks, Resizable BAR' }
        @{ Section = 'Hardware'; Category = 'Input'; Group = ''; Line = 'Mouse polling in background windows' }

        # Advanced
        @{ Section = 'Advanced'; Category = 'System'; Group = 'System'; Line = 'Prefetch, reserved storage, the NVMe driver, the Start and Search hosts' }
        @{ Section = 'Advanced'; Category = 'Services'; Group = 'System'; Line = 'Every Windows service''s startup type, or most of them off at once' }
        @{ Section = 'Advanced'; Category = 'Scheduled tasks'; Group = 'System'; Line = 'Every scheduled task on or off, or all of them removed' }
        @{ Section = 'Advanced'; Category = 'Tuning'; Group = 'System'; Line = 'Processor scheduling and the service host split' }
        @{ Section = 'Advanced'; Category = 'Display'; Group = 'System'; Line = 'Flip models and multiplane overlay' }
        @{ Section = 'Advanced'; Category = 'Security'; Group = 'Security and features'; Line = 'Microsoft Defender, the firewall, SmartScreen, Spectre and Meltdown, core isolation' }
        @{ Section = 'Advanced'; Category = 'Features'; Group = 'Security and features'; Line = '.NET 3.5, Hyper-V, Sandbox, WSL, OpenSSH Server, F8 recovery' }

        # Tools
        @{ Section = 'Tools'; Category = 'Setup'; Group = 'Keep it running'; Line = 'A restore point, activation, Home to Pro, updating every app' }
        @{ Section = 'Tools'; Category = 'Drivers'; Group = 'Keep it running'; Line = 'The latest NVIDIA, AMD and Intel drivers, a DDU clean, Snappy Driver Installer, controller overclock' }
        @{ Section = 'Tools'; Category = 'Startup'; Group = 'Keep it running'; Line = 'Every app that starts with Windows on or off, or all of them removed' }
        @{ Section = 'Tools'; Category = 'Cleanup'; Group = 'Keep it running'; Line = 'Temporary files, Windows.old, logs, old drivers' }
        @{ Section = 'Tools'; Category = 'Fixes'; Group = 'Keep it running'; Line = 'Windows Update reset, network reset, corruption scan, WinGet reinstall' }
        @{ Section = 'Tools'; Category = 'Check'; Group = 'Check and recover'; Line = 'BIOS, storage, RAM, GPU and polling rate tests, O&O ShutUp10++' }
        @{ Section = 'Tools'; Category = 'Refresh'; Group = 'Check and recover'; Line = 'Reinstall Windows, factory reset, Gaming Services repair, restart to BIOS' }
        @{ Section = 'Tools'; Category = 'Panels'; Group = 'Check and recover'; Line = 'Control Panel, Network Connections, Power Options and the other classic panels' }
    )
}
