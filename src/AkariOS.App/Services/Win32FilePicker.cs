using System.Runtime.InteropServices;

namespace AkariOS.App.Services;

/// <summary>
/// Classic Win32 open-file dialog (comdlg32). Used instead of WinRT's FileOpenPicker
/// because the WinRT picker broker cannot launch from an elevated (admin) process
/// and throws E_FAIL — this one works fine elevated.
/// </summary>
public static partial class Win32FilePicker
{
    [Flags]
    private enum OfnFlags : uint
    {
        OverwritePrompt = 0x2,
        FileMustExist = 0x1000,
        PathMustExist = 0x800,
        NoChangeDir = 0x8,
        AllowMultiselect = 0x200,
        Explorer = 0x80000,
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct OPENFILENAMEW
    {
        public uint lStructSize;
        public IntPtr hwndOwner;
        public IntPtr hInstance;
        public IntPtr lpstrFilter;
        public IntPtr lpstrCustomFilter;
        public uint nMaxCustFilter;
        public uint nFilterIndex;
        public IntPtr lpstrFile;
        public uint nMaxFile;
        public IntPtr lpstrFileTitle;
        public uint nMaxFileTitle;
        public IntPtr lpstrInitialDir;
        public IntPtr lpstrTitle;
        public OfnFlags flags;
        public ushort nFileOffset;
        public ushort nFileExtension;
        public IntPtr lpstrDefExt;
        public IntPtr lCustData;
        public IntPtr lpfnHook;
        public IntPtr lpTemplateName;
        public IntPtr pvReserved;
        public uint dwReserved;
        public uint flagsEx;
    }

    [LibraryImport("comdlg32.dll", EntryPoint = "GetOpenFileNameW", StringMarshalling = StringMarshalling.Utf16)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool GetOpenFileName(ref OPENFILENAMEW ofn);

    /// <summary>Shows a single-select .iso open dialog. Returns null if cancelled.</summary>
    public static unsafe string? PickIso(IntPtr ownerHwnd)
    {
        const int maxFile = 0x7FFF; // generous buffer
        var fileNameBuffer = Marshal.AllocCoTaskMem(maxFile * sizeof(char));
        var filterBuffer = Marshal.StringToCoTaskMemUni(
            "Windows ISO images (*.iso)\0*.iso\0All files (*.*)\0*.*\0");
        try
        {
            var ofn = new OPENFILENAMEW
            {
                lStructSize = (uint)sizeof(OPENFILENAMEW),
                hwndOwner = ownerHwnd,
                lpstrFilter = filterBuffer,
                nFilterIndex = 1,
                lpstrFile = fileNameBuffer,
                nMaxFile = maxFile,
                lpstrTitle = Marshal.StringToCoTaskMemUni("Select Windows ISO"),
                flags = OfnFlags.FileMustExist | OfnFlags.PathMustExist | OfnFlags.NoChangeDir,
            };
            if (!GetOpenFileName(ref ofn))
                return null; // cancelled / error
            return Marshal.PtrToStringUni(fileNameBuffer);
        }
        finally
        {
            Marshal.FreeCoTaskMem(fileNameBuffer);
            Marshal.FreeCoTaskMem(filterBuffer);
        }
    }
}
