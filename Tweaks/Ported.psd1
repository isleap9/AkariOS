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
    # 6 Windows\24-30, 35 (Task 6). Not listed yet: control-panel (focus / priority notification blobs, app actions and
    # the Explorer "IsEnabled" value are not ported), copilot (no Copilot app removal), gamebar (its Revert reinstalls
    # the Xbox apps), notepad (needs loading Notepad's settings hive).
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
}
