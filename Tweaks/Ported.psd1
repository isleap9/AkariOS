# Legacy id -> the one-file Tweak ids that fully replace it (ADR 0004). Guided hides a legacy row listed here;
# Optimize > Legacy keeps it. List a legacy id only when everything it does (Apply and Default) has a one-file owner.
@{
    # Edge and WebView: removed in Apps > Remove, put back from Downloads
    'edge-webview' = @('remove-edge', 'remove-webview2', 'install-microsoft-edge', 'install-webview2-runtime')
}
