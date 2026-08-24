using System.Runtime.InteropServices;

namespace AkariOS.App.Services;

/// <summary>
/// When running elevated, UIPI blocks drag-drop messages from unelevated processes
/// (like Explorer), so dropping files onto the window silently does nothing.
/// Allowing the three drag-drop related messages through the filter restores it.
/// </summary>
public static class UiPiDragDropFix
{
    private const uint WM_DROPFILES = 0x0233;
    private const uint WM_COPYDATA = 0x004A;
    private const uint WM_CHANGECBCHAIN = 0x0308; // 0x049? — legacy clipboard-manager message allowed alongside

    // Use process-wide ChangeWindowMessageFilter (not Ex) so all current/future windows are covered.
    [DllImport("user32.dll")]
    private static extern bool ChangeWindowMessageFilter(uint message, uint dwFlag);

    private const uint MSGFLT_ALLOW = 1;

    public static void AllowDragDropMessages()
    {
        ChangeWindowMessageFilter(WM_DROPFILES, MSGFLT_ALLOW);
        ChangeWindowMessageFilter(WM_COPYDATA, MSGFLT_ALLOW);
        ChangeWindowMessageFilter(0x0049, MSGFLT_ALLOW);
    }
}
