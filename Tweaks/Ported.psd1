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
}
