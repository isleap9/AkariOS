# Legacy id -> the one-file Tweak ids that fully replace it (ADR 0004). Guided hides a legacy row listed here;
# Optimize > Legacy keeps it. List a legacy id only when everything it does (Apply and Default) has a one-file owner.
@{
    # Edge and WebView: removed in Apps > Remove, put back from Downloads
    'edge-webview'    = @('remove-edge', 'remove-webview2', 'install-microsoft-edge', 'install-webview2-runtime')
    # 6 Windows\1 Start Menu Taskbar (its Default's AuxilliaryPins MailPin is not ported: the Mail app is gone)
    'start-taskbar'   = @('taskbar-align-left', 'taskbar-hide-search', 'taskbar-hide-task-view', 'taskbar-hide-chat', 'taskbar-hide-copilot',
                          'taskbar-disable-widgets', 'taskbar-disable-news-interests', 'taskbar-hide-meet-now', 'taskbar-hide-security-icon',
                          'taskbar-show-all-tray-icons', 'taskbar-unpin-all', 'start-hide-recommended', 'start-new-menu', 'start-all-apps-list',
                          'start-hide-accessibility-folders', 'start-akarios-pins')
    # 6 Windows\2 Start Menu Layout
    'start-layout'    = @('start-new-menu', 'start-all-apps-list')
    # 6 Windows\3 Start Menu Shortcuts
    'start-shortcuts' = @('start-akarios-shortcuts')
    # 6 Windows\8 Widgets
    'widgets'         = @('taskbar-disable-widgets')
    # 6 Windows\4 Context Menu
    'context-menu'      = @('explorer-classic-context-menu', 'explorer-trim-context-menu')
    # 6 Windows\5 Theme Black (its Control Panel\Colors Background "0 0 0" is the Default already)
    'theme-black'       = @('theme-dark-mode', 'theme-no-transparency', 'theme-black-accent')
    # 6 Windows\6 Signout Lockscreen Wallpaper Black (the black desktop wallpaper is now the AkariOS wallpaper)
    'signout-wallpaper' = @('theme-black-lock-screen', 'theme-no-signin-blur', 'theme-akarios-wallpaper')
    # 6 Windows\7 User Account Pictures Black
    'account-pictures'  = @('theme-black-account-pictures')
    # 6 Windows\24-30, 35 (Task 6)
    'power-plan'        = @('power-ultimate-plan', 'power-hibernate-off', 'power-fast-startup-off', 'power-throttling-off', 'power-hide-lock-sleep')
    'timer-resolution'  = @('performance-timer-resolution')
    'write-cache'       = @('performance-write-cache-flushing-off')
    'devmgr-power'      = @('power-device-power-saving-off')
    'netadapter-power'  = @('power-network-adapter-power-saving-off')
    'ipv4-only'         = @('network-ipv4-only')
    'cleanup'           = @('performance-clean-temp')
    'loudness-eq'       = @('sound-loudness-eq-tab')
    # 3 Setup rows a 6 Windows port already covers (same values, same Defaults)
    'memory-compression' = @('disable-memory-compression')
    'background-apps'    = @('performance-background-apps-off')
    # 8 Advanced. Not listed: rebar, smt-ht, core1-thread1, priority (per-game tools, not settings); ulps (Graphics).
    # adv-defender's Default Definitions feature removal is feature/Windows-Defender-Default-Definitions on Apps > Remove.
    'adv-defender'       = @('security-defender-settings', 'security-defender-tasks-off', 'security-defender-off')
    'services'           = @('advanced-services-off')
    'firewall'           = @('security-firewall-off')
    'spectre-meltdown'   = @('security-spectre-meltdown-off')
    'dep'                = @('security-dep-off')
    'download-warning'   = @('security-download-warning-off')
    'whql-bypass'        = @('security-whql-secure-boot-bypass')
    'mmagent'            = @('system-mmagent-off', 'disable-memory-compression')
    'mpo'                = @('display-mpo-off', 'gaming-windowed-optimizations')
    'hw-legacy-flip'     = @('display-fullscreen-exclusive')
    'hw-composed-flip'   = @('display-composed-independent-flip')
    'keyboard-shortcuts' = @('system-keyboard-shortcuts-off')
    'start-search-shell' = @('system-start-search-shell-off', 'taskbar-hide-search')
    'nvme-driver'        = @('system-nvme-native-driver')
    'ulps'               = @('graphics-amd-ulps-off')
    # 5 Graphics and 7 Hardware (Toggles). Driver clean / installs, DirectX, C++ and the Open / test Actions stay Legacy.
    'hdcp'               = @('graphics-hdcp-off')
    'p0-state'           = @('graphics-p0-state')
    'msi-mode'           = @('graphics-msi-mode')
    'intel-settings'     = @('graphics-intel-settings', 'gaming-windowed-optimizations')
    'nvidia-settings'    = @('graphics-nvidia-settings')
    'amd-settings'       = @('graphics-amd-settings')
    'bg-polling-cap'     = @('input-background-polling-uncapped')
    # 3 Setup (Toggles). Not listed: edge-settings (its updater / service removal is remove-edge's, its Default
    # reinstalled Edge); the Open / Run Actions stay Legacy.
    'bitlocker'          = @('performance-bitlocker-off')
    'store-settings'     = @('apps-store-settings', 'update-store-auto-update')
    'updates-pause'      = @('update-pause-one-year')
    # 6 Windows security parts and Notepad (M4: Safe Mode through Core\Phases.ps1). Not listed: core-isolation (an Open
    # button).
    'uac'                = @('security-uac-off')
    'defender'           = @('security-defender-settings', 'security-defender-tasks-off')
    'notepad'            = @('apps-notepad-settings')
    # Optimize › Advanced batch 1 (2026-10-22): 6 Windows leftovers. The Open buttons became Actions (Advanced only).
    'gamemode'           = @('gaming-open-game-mode')
    'pointer-precision'  = @('input-open-pointer-options')
    'scaling'            = @('system-open-display-scaling')
    'sound'              = @('sound-open-classic-panel')
    'core-isolation'     = @('security-open-core-isolation')
    'copilot'            = @('privacy-copilot-ai', 'appx/Microsoft.Copilot')
    # gamebar's Default reinstalls the Xbox apps (Downloads › Restore removed apps), WebView2 and Gaming Services
    'gamebar'            = @('disable-game-dvr', 'gaming-capture-off', 'gaming-xbox-controller-no-game-bar', 'gaming-presence-writer-off',
                             'appx/Microsoft.GamingApp', 'appx/Microsoft.XboxGamingOverlay', 'appx/Microsoft.XboxGameOverlay',
                             'appx/Microsoft.XboxIdentityProvider', 'appx/Microsoft.XboxSpeechToTextOverlay', 'appx/Microsoft.Xbox.TCUI',
                             'remove-gameinput', 'store/Microsoft.GamingApp', 'store/Microsoft.XboxGamingOverlay', 'install-webview2-runtime',
                             'tools-gaming-repair')
    # 6 Windows\22 Control Panel Settings: every one-file Tweak ported from it (their header names it), the last ones
    # in batch 1 (Resume on the taskbar, do not disturb rules, priority list, app actions)
    'control-panel'      = @('accessibility-shortcuts-off', 'apps-app-actions-off', 'explorer-desktop-recycle-bin', 'explorer-folder-options',
                             'explorer-hide-3d-objects', 'explorer-hide-frequent-folders', 'explorer-hide-gallery', 'explorer-hide-home',
                             'explorer-hide-network', 'explorer-hide-office-files', 'explorer-open-this-pc', 'explorer-show-extensions',
                             'explorer-show-hidden-files', 'gaming-capture-off', 'gaming-game-mode', 'gaming-hags', 'gaming-presence-writer-off',
                             'gaming-windowed-optimizations', 'gaming-xbox-controller-no-game-bar', 'input-language-bar', 'input-no-cursor-scheme',
                             'input-no-print-screen-snipping', 'input-pointer-precision-off', 'input-touch-keyboard', 'input-typing',
                             'network-no-ics-control', 'notifications-no-auto-dnd', 'notifications-no-suggestions', 'notifications-off',
                             'notifications-priority-list-empty', 'notifications-quiet', 'performance-background-apps-off',
                             'performance-defrag-schedule-off', 'performance-maintenance-off', 'performance-storage-sense-off',
                             'performance-visual-effects', 'power-hide-lock-sleep', 'power-no-sign-in-after-sleep', 'power-video-on-battery',
                             'privacy-activity-history', 'privacy-ads', 'privacy-app-permissions', 'privacy-copilot-ai', 'privacy-find-my-device',
                             'privacy-inking-typing', 'privacy-location', 'privacy-remote-assistance', 'privacy-search-highlights',
                             'privacy-telemetry', 'privacy-voice-activation', 'privacy-web-search', 'sound-communications-do-nothing',
                             'sound-no-scheme', 'sound-no-startup-sound', 'start-compact-layout', 'start-hide-account-notifications',
                             'start-hide-browsing-sites', 'start-hide-most-used', 'start-hide-pinned-section', 'start-hide-recent-items',
                             'start-hide-recently-added', 'start-hide-suggestions', 'start-more-pins', 'system-100-percent-scaling',
                             'system-alt-tab-windows-only', 'system-black-console', 'system-bsod-details', 'system-default-printer',
                             'system-long-paths', 'system-menu-show-delay', 'system-no-autoplay', 'system-no-cross-device',
                             'system-no-dynamic-lighting', 'system-no-troubleshooters', 'system-no-web-services', 'system-no-windows-backup',
                             'system-no-wpbt', 'system-password-sign-in', 'system-settings-hide-home', 'system-snap', 'system-terminal-not-default',
                             'taskbar-end-task', 'taskbar-far-corner-desktop', 'taskbar-hide-resume', 'taskbar-never-small-icons',
                             'taskbar-no-share-window', 'theme-akarios-wallpaper', 'update-delivery-optimization', 'update-maps-auto-update',
                             'update-no-app-archiving', 'update-no-driver-updates', 'update-store-auto-update', 'win32-priority-separation')
}
