using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace AkariOS.App.Views;

public sealed partial class SystemCheckPage : WizardStepPage
{
    public SystemCheckPage()
    {
        InitializeComponent();
        Loaded += (_, _) => FillSpecs();
    }

    public override WizardStepKind Kind => WizardStepKind.SystemCheck;

    private unsafe void FillSpecs()
    {
        try
        {
            // Lightweight native queries — no WMI dependency needed for Slice 1.
            var arch = Environment.Is64BitOperatingSystem ? "x64" : "x86";
            var cores = Environment.ProcessorCount;
            var build = Environment.OSVersion.Version.Build;
            var mem = GetRamGb();

            SpecText.Text = $"CPU cores: {cores}\nRAM: {mem:N1} GB\nOS build: {build} ({arch})";
        }
        catch (Exception ex)
        {
            SpecText.Text = $"Could not read system info: {ex.Message}";
        }
    }

    private static string GetRamGb()
    {
        try
        {
            var status = GlobalMemoryStatusEx();
            return (status.ullTotalPhys / (1024d * 1024 * 1024)).ToString("N1");
        }
        catch { return "?"; }
    }

    [System.Runtime.InteropServices.StructLayout(System.Runtime.InteropServices.LayoutKind.Sequential)]
    private struct MEMORYSTATUSEX
    {
        public uint dwLength;
        public uint dwMemoryLoad;
        public ulong ullTotalPhys;
        public ulong ullAvailPhys;
        public ulong ullTotalPageFile;
        public ulong ullAvailPageFile;
        public ulong ullTotalVirtual;
        public ulong ullAvailVirtual;
        public ulong ullAvailExtendedVirtual;
    }

    [System.Runtime.InteropServices.DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GlobalMemoryStatusEx(ref MEMORYSTATUSEX lpBuffer);

    private static MEMORYSTATUSEX GlobalMemoryStatusEx()
    {
        var s = new MEMORYSTATUSEX { dwLength = (uint)System.Runtime.InteropServices.Marshal.SizeOf<MEMORYSTATUSEX>() };
        if (!GlobalMemoryStatusEx(ref s)) throw new System.ComponentModel.Win32Exception();
        return s;
    }
}
