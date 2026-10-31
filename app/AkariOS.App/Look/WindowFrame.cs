using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;

namespace AkariOS.App.Look;

/// <summary>
/// The window's frame (Shell.ps1's SourceInitialized and Update-AkariFrame): no system menu (Windows stops drawing
/// its caption buttons under Akari's), Mica behind the window on Windows 11, the dark frame for the dark theme, the
/// body on Tint over Mica (dark only) or the solid Bg, and Windows' theme changes followed while the setting is System.
/// </summary>
public static partial class WindowFrame
{
    /// <summary>The DWM attribute and value that turn Mica on for a build, or null (Windows 10). Pure.</summary>
    public static (int Attribute, int Value)? Backdrop(int build) => build switch
    {
        >= 22621 => (38, 2), // DWMWA_SYSTEMBACKDROP_TYPE = DWMSBT_MAINWINDOW
        >= 22000 => (1029, 1), // the first Windows 11 release's undocumented Mica switch
        _ => null,
    };

    /// <summary>The body's brush key: Tint over Mica in dark only, else the solid Bg. Pure.</summary>
    public static string BodyBrush(bool mica, string theme) => mica && theme == "Dark" ? "Tint" : "Bg";

    private const int WmSettingChange = 0x001A;

    /// <summary>
    /// Hooks a window: the frame once it has a handle, again on every theme change, and Windows' own theme changes.
    /// Body: the element painted with Tint or Bg.
    /// </summary>
    public static void Attach(Window window, FrameworkElement body, ThemeService theme)
    {
        var mica = false;
        void Paint()
        {
            body.SetResourceReference(System.Windows.Controls.Border.BackgroundProperty, BodyBrush(mica, theme.Current));
            var h = new WindowInteropHelper(window).Handle;
            if (h == IntPtr.Zero) return;
            var dark = theme.Current == "Dark" ? 1 : 0;
            DwmSetWindowAttribute(h, 20, ref dark, 4);
        }
        theme.Changed += Paint;
        window.SourceInitialized += (_, _) =>
        {
            var h = new WindowInteropHelper(window).Handle;
            SetWindowLongPtrW(h, -16, (IntPtr)(GetWindowLongPtrW(h, -16).ToInt64() & ~0x80000L));
            if (Backdrop(Environment.OSVersion.Version.Build) is var (attribute, value))
            {
                HwndSource.FromHwnd(h)!.CompositionTarget.BackgroundColor = Colors.Transparent;
                mica = DwmSetWindowAttribute(h, attribute, ref value, 4) == 0;
            }
            Paint();
            HwndSource.FromHwnd(h)!.AddHook((IntPtr _, int msg, IntPtr _, IntPtr lParam, ref bool _) =>
            {
                if (msg == WmSettingChange && theme.Setting == "System" && lParam != IntPtr.Zero && Marshal.PtrToStringUni(lParam) == "ImmersiveColorSet")
                    theme.Apply("System");
                return IntPtr.Zero;
            });
        };
        Paint();
    }

    [LibraryImport("dwmapi.dll")]
    private static partial int DwmSetWindowAttribute(IntPtr hwnd, int attribute, ref int value, int size);

    [LibraryImport("user32.dll")]
    private static partial IntPtr GetWindowLongPtrW(IntPtr hwnd, int index);

    [LibraryImport("user32.dll")]
    private static partial IntPtr SetWindowLongPtrW(IntPtr hwnd, int index, IntPtr value);
}
