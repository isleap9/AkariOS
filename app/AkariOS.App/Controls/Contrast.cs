namespace AkariOS.App.Controls;

/// <summary>
/// High contrast for the look's decoration (the aurora, the bloom, the nav icons' colours). An unpackaged WinUI 3 app
/// has no CoreWindow, so <c>AccessibilitySettings.HighContrastChanged</c> can't be subscribed (it throws 0x80070490
/// and the app never opened): <see cref="On"/> reads the setting (never throws: false when it can't), and
/// <see cref="Changed"/> follows it through <c>UISettings.ColorValuesChanged</c>, which Windows raises when high
/// contrast turns on or off. <see cref="Changed"/> comes on a background thread: handlers post to their own queue.
/// </summary>
public static class Contrast
{
    private static readonly object Gate = new();
    private static Windows.UI.ViewManagement.UISettings? _settings;
    private static bool _last;
    private static event Action? ChangedCore;

    public static bool On
    {
        get
        {
            try { return new Windows.UI.ViewManagement.AccessibilitySettings().HighContrast; }
            catch { return false; }
        }
    }

    public static event Action? Changed
    {
        add
        {
            lock (Gate)
            {
                ChangedCore += value;
                Hook();
            }
        }
        remove
        {
            lock (Gate) ChangedCore -= value;
        }
    }

    // one UISettings for the app, kept alive here (its event stops when it is collected); a failure = not followed
    private static void Hook()
    {
        if (_settings is not null) return;
        try
        {
            var settings = new Windows.UI.ViewManagement.UISettings();
            _last = On;
            settings.ColorValuesChanged += (_, _) =>
            {
                var now = On;
                Action? handlers;
                lock (Gate)
                {
                    if (now == _last) return;
                    _last = now;
                    handlers = ChangedCore;
                }
                handlers?.Invoke();
            };
            _settings = settings;
        }
        catch
        {
            // left unfollowed: the setting is read again on each Loaded and theme change
        }
    }
}
