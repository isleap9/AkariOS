# ── AkariOS Setup — startup / initialization ────────────────────────────────
# Ported from AkariTool/scripts/start.ps1. This file is the FIRST block of the
# compiled akarios.ps1: it must establish elevation, process identity, the WPF
# assemblies and the shared $sync state before anything else runs.

# ── Web launch URL (used to re-elevate when started via `irm <url> | iex`,
#    where there is no script file on disk to re-run) ────────────────────────
$AkariOSUrl = "https://raw.githubusercontent.com/isleap9/AkariOS/main/AkariOS/akarios.ps1"

# ── Admin elevation (PREF-03) ───────────────────────────────────────────────
$akariosIsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")

If (-not $akariosIsAdmin) {
    # Start-Process -Verb RunAs throws a Win32Exception when the UAC prompt is
    # dismissed, so a successful return means an elevated child is now running.
    $elevated = $false
    try {
        if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath)) {
            # Normal case: relaunch the local file elevated
            Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs | Out-Null
        } else {
            # Launched via `irm <url> | iex` (no file on disk): re-fetch and run elevated
            Start-Process PowerShell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -Command `"irm {0} | iex`"" -f $AkariOSUrl) -Verb RunAs | Out-Null
        }
        $elevated = $true
    } catch {
        $elevated = $false
    }

    # PREF-03: elevation declined (UAC dismissed) — say so clearly and stop.
    if (-not $elevated) {
        try {
            Add-Type -AssemblyName PresentationFramework
            [System.Windows.MessageBox]::Show(
                "AkariOS Setup needs administrator rights to install Windows components.`n`n" +
                "The Windows UAC prompt was declined or dismissed. Right-click akarios.ps1 and " +
                "choose 'Run as administrator', then accept the prompt.",
                "AkariOS Setup") | Out-Null
        } catch {
            # No WPF available (e.g. PowerShell ISE host) — fall back to console.
            Write-Host "AkariOS Setup requires administrator rights. Re-run as administrator." -ForegroundColor Red
        }
    }
    Exit
}

# ── Taskbar identity + console handling (custom taskbar identity, no PS console) ──
Add-Type -Namespace AkariOS -Name Native -MemberDefinition @"
[System.Runtime.InteropServices.DllImport("shell32.dll", SetLastError=true)]
public static extern int SetCurrentProcessExplicitAppUserModelID(string AppID);
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern System.IntPtr GetConsoleWindow();
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
"@
# Give the process its own taskbar identity so it shows as "AkariOS Setup" instead
# of grouping under powershell.exe.
try { [AkariOS.Native]::SetCurrentProcessExplicitAppUserModelID("AkariOS.Setup") | Out-Null } catch {}
# Hide the PowerShell console window so only the app window appears in the taskbar.
try {
    $consoleWnd = [AkariOS.Native]::GetConsoleWindow()
    if ($consoleWnd -ne [IntPtr]::Zero) { [AkariOS.Native]::ShowWindow($consoleWnd, 0) | Out-Null }  # 0 = SW_HIDE
} catch {}

# ── WPF assemblies ──────────────────────────────────────────────────────────
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# ── DWM P/Invoke  (Mica backdrop + dark title bar on Win11) ─────────────────
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class DwmApi {
    // Mica / Acrylic backdrop
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

    // Extend frame into client area (required for Mica)
    [DllImport("dwmapi.dll")]
    public static extern int DwmExtendFrameIntoClientArea(IntPtr hwnd, ref MARGINS pMarInset);

    [StructLayout(LayoutKind.Sequential)]
    public struct MARGINS { public int Left, Right, Top, Bottom; }
}
"@

# ── Shared state across runspaces ────────────────────────────────────────────
$sync             = [Hashtable]::Synchronized(@{})
$sync.configs     = @{}
$sync.runspaces   = [System.Collections.Generic.List[hashtable]]::new()
$sync.app         = @{
    Name           = "AkariOS Setup"
    AppUserModelId = "AkariOS.Setup"
    StatePath      = "C:\ProgramData\AkariOS\state.json"
    LogPath        = "C:\ProgramData\AkariOS\install.log"
    ConfirmToken   = "AKARIOS"
    TotalStages    = 3
    IsAdmin        = $akariosIsAdmin
}