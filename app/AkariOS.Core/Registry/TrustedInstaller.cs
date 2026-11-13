using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.ExceptionServices;
using System.Runtime.InteropServices;
using System.ServiceProcess;

namespace AkariOS.Core.Registry;

/// <summary>Runs work as TrustedInstaller, for keys an admin can't change (Defender's): Invoke-AkariRegistryTrusted.</summary>
public interface ITrustedInstaller
{
    void Run(Action work);

    /// <summary>A program run as TrustedInstaller (Run-Trusted: schtasks for a task Windows keeps from an admin),
    /// waited for (a minute at most); its exit code.</summary>
    int Start(string exe, string arguments) => throw new NotSupportedException("this TrustedInstaller can't start programs");
}

/// <summary>
/// The real one: starts the TrustedInstaller service, borrows SYSTEM's token from winlogon.exe to open
/// TrustedInstaller.exe's, and runs the work on a thread impersonating it (registry calls on that thread are checked
/// against TrustedInstaller). No service command line is rewritten, unlike the PowerShell app's Run-Trusted.
/// </summary>
public sealed partial class TrustedInstaller : ITrustedInstaller
{
    public TrustedInstaller() => SystemGuard.Check("TrustedInstaller");

    public void Run(Action work)
    {
        EnablePrivilege("SeDebugPrivilege");
        EnablePrivilege("SeImpersonatePrivilege");
        var ti = StartService();
        ExceptionDispatchInfo? error = null;
        var thread = new Thread(() =>
        {
            try
            {
                using (var system = TokenOf(Process.GetProcessesByName("winlogon").First(p => p.SessionId == Process.GetCurrentProcess().SessionId)))
                    Impersonate(system);
                using (var trusted = TokenOf(Process.GetProcessById(ti)))
                    Impersonate(trusted);
                try { work(); }
                finally { RevertToSelf(); }
            }
            catch (Exception e) { error = ExceptionDispatchInfo.Capture(e); }
        });
        thread.Start();
        thread.Join();
        error?.Throw();
    }

    /// <summary>A process with a primary copy of TrustedInstaller.exe's token (CreateProcessWithTokenW, from a thread
    /// impersonating SYSTEM), no window, waited for a minute at most.</summary>
    public int Start(string exe, string arguments)
    {
        EnablePrivilege("SeDebugPrivilege");
        EnablePrivilege("SeImpersonatePrivilege");
        var ti = StartService();
        var code = -1;
        ExceptionDispatchInfo? error = null;
        var thread = new Thread(() =>
        {
            try
            {
                using (var system = TokenOf(Process.GetProcessesByName("winlogon").First(p => p.SessionId == Process.GetCurrentProcess().SessionId)))
                    Impersonate(system);
                try
                {
                    using var primary = TokenOf(Process.GetProcessById(ti), TokenPrimary);
                    var si = new StartupInfo { Size = Marshal.SizeOf<StartupInfo>() };
                    var line = $"\"{exe}\" {arguments}";
                    if (!CreateProcessWithTokenW(primary.Handle, 0, exe, line, CreateNoWindow, IntPtr.Zero, null, ref si, out var pi))
                        throw new Win32Exception(Marshal.GetLastWin32Error(), $"{exe} did not start as TrustedInstaller");
                    try
                    {
                        WaitForSingleObject(pi.Process, 60_000);
                        code = GetExitCodeProcess(pi.Process, out var c) ? (int)c : -1;
                    }
                    finally { CloseHandle(pi.Process); CloseHandle(pi.Thread); }
                }
                finally { RevertToSelf(); }
            }
            catch (Exception e) { error = ExceptionDispatchInfo.Capture(e); }
        });
        thread.Start();
        thread.Join();
        error?.Throw();
        return code;
    }

    private const int TokenPrimary = 1;
    private const uint CreateNoWindow = 0x08000000;

    [StructLayout(LayoutKind.Sequential)]
    private struct StartupInfo
    {
        public int Size;
        public IntPtr Reserved, Desktop, Title;
        public int X, Y, XSize, YSize, XCountChars, YCountChars, FillAttribute, Flags;
        public short ShowWindow, Reserved2;
        public IntPtr Reserved3, StdInput, StdOutput, StdError;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct ProcessInformation
    {
        public IntPtr Process, Thread;
        public int ProcessId, ThreadId;
    }

    [LibraryImport("advapi32.dll", SetLastError = true, StringMarshalling = StringMarshalling.Utf16)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool CreateProcessWithTokenW(IntPtr token, uint logonFlags, string application, string commandLine, uint creationFlags,
        IntPtr environment, string? currentDirectory, ref StartupInfo startup, out ProcessInformation info);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    private static partial uint WaitForSingleObject(IntPtr handle, uint milliseconds);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool GetExitCodeProcess(IntPtr process, out uint code);

    private static int StartService()
    {
        using var sc = new ServiceController("TrustedInstaller");
        if (sc.Status != ServiceControllerStatus.Running)
        {
            sc.Start();
            sc.WaitForStatus(ServiceControllerStatus.Running, TimeSpan.FromSeconds(20));
        }
        return Process.GetProcessesByName("TrustedInstaller").FirstOrDefault()?.Id
            ?? throw new InvalidOperationException("TrustedInstaller.exe is not running");
    }

    private sealed class Token(IntPtr handle) : IDisposable
    {
        public IntPtr Handle { get; } = handle;
        public void Dispose() => CloseHandle(Handle);
    }

    private static Token TokenOf(Process p, int type = TokenImpersonation)
    {
        using (p)
        {
            var process = OpenProcess(ProcessQueryInformation, false, (uint)p.Id);
            if (process == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error(), $"can't open {p.ProcessName}");
            try
            {
                if (!OpenProcessToken(process, TokenDuplicate | TokenQuery, out var token)) throw new Win32Exception(Marshal.GetLastWin32Error());
                try
                {
                    if (!DuplicateTokenEx(token, TokenAllAccess, IntPtr.Zero, SecurityImpersonation, type, out var dup))
                        throw new Win32Exception(Marshal.GetLastWin32Error());
                    return new Token(dup);
                }
                finally { CloseHandle(token); }
            }
            finally { CloseHandle(process); }
        }
    }

    private static void Impersonate(Token t)
    {
        if (!SetThreadToken(IntPtr.Zero, t.Handle)) throw new Win32Exception(Marshal.GetLastWin32Error());
    }

    /// <summary>A privilege of this process turned on (SeDebug here; the ISO Builder's hive loads: SeBackup, SeRestore).</summary>
    internal static void EnablePrivilege(string name)
    {
        if (!OpenProcessToken(Process.GetCurrentProcess().Handle, TokenAdjustPrivileges | TokenQuery, out var token)) throw new Win32Exception(Marshal.GetLastWin32Error());
        try
        {
            if (!LookupPrivilegeValueW(null, name, out var luid)) throw new Win32Exception(Marshal.GetLastWin32Error());
            var tp = new TokenPrivileges { Count = 1, Luid = luid, Attributes = SePrivilegeEnabled };
            if (!AdjustTokenPrivileges(token, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero)) throw new Win32Exception(Marshal.GetLastWin32Error());
        }
        finally { CloseHandle(token); }
    }

    private const uint ProcessQueryInformation = 0x0400;
    private const uint TokenAdjustPrivileges = 0x0020, TokenQuery = 0x0008, TokenDuplicate = 0x0002, TokenAllAccess = 0xF01FF;
    private const int SecurityImpersonation = 2, TokenImpersonation = 2;
    private const uint SePrivilegeEnabled = 0x2;

    [StructLayout(LayoutKind.Sequential)]
    private struct TokenPrivileges
    {
        public uint Count;
        public long Luid;
        public uint Attributes;
    }

    [LibraryImport("kernel32.dll", SetLastError = true)]
    private static partial IntPtr OpenProcess(uint access, [MarshalAs(UnmanagedType.Bool)] bool inherit, uint pid);

    [LibraryImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool CloseHandle(IntPtr handle);

    [LibraryImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool OpenProcessToken(IntPtr process, uint access, out IntPtr token);

    [LibraryImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool DuplicateTokenEx(IntPtr token, uint access, IntPtr attributes, int level, int type, out IntPtr dup);

    [LibraryImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool SetThreadToken(IntPtr thread, IntPtr token);

    [LibraryImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool RevertToSelf();

    [LibraryImport("advapi32.dll", SetLastError = true, StringMarshalling = StringMarshalling.Utf16)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool LookupPrivilegeValueW(string? system, string name, out long luid);

    [LibraryImport("advapi32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static partial bool AdjustTokenPrivileges(IntPtr token, [MarshalAs(UnmanagedType.Bool)] bool disableAll, ref TokenPrivileges state, uint length, IntPtr previous, IntPtr returned);
}
