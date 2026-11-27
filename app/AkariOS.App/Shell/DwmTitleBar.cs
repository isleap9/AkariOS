using System.Runtime.InteropServices;

namespace AkariOS.App.Shell;

/// <summary>
/// Windows' own title bar in the app's theme: DWM's immersive dark mode (Windows 10 20H1 and later). Without it the
/// caption stays light while the app is dark.
/// </summary>
internal static partial class DwmTitleBar
{
    private const int UseImmersiveDarkMode = 20;

    [LibraryImport("dwmapi.dll")]
    private static partial int DwmSetWindowAttribute(nint hwnd, int attribute, ref int value, int size);

    public static void SetDark(nint hwnd, bool dark)
    {
        var value = dark ? 1 : 0;
        _ = DwmSetWindowAttribute(hwnd, UseImmersiveDarkMode, ref value, sizeof(int));
    }
}
