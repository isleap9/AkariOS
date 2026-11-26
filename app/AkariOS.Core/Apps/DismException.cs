namespace AkariOS.Core.Apps;

/// <summary>A DISM call that failed: its message and HRESULT.</summary>
public sealed class DismException(string message, int code) : InvalidOperationException(message)
{
    /// <summary>CBS_E_CANNOT_UNINSTALL: the package is a permanent part of Windows.</summary>
    public const int CannotUninstall = unchecked((int)0x800F0825);

    public int Code => code;
}
