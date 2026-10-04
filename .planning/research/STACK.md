# Stack Research

**Domain:** Windows 11 GUI wrapper for multi-reboot system modification engine (PowerShell + WPF)
**Researched:** 2025-10-04
**Confidence:** HIGH (mechanisms verified against Microsoft Learn, WinSux source, and AkariTool reference implementation)

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| PowerShell | 5.1 (Win11 inbox) | Script engine + WPF host | Native to Windows 11; no runtime install needed. AkariTool already proves the pattern: single-file .ps1 compiled by concatenation, XAML loaded via `[Windows.Markup.XamlReader]::Parse`, synchronized `$sync` hashtable for cross-runspace state. |
| WPF (PresentationFramework) | .NET Framework 4.8 (inbox) | GUI layer | Hardware-accelerated rendering with Mica backdrop via DWM P/Invoke. AkariTool's `DwmApi` class (DwmSetWindowAttribute for Mica/dark title bar) is directly reusable. |
| WinSux engine | FR33THY main branch | 3-stage modification pipeline | Stage 1 (winsux.ps1): downloads payloads, sets `bcdedit safeboot minimal` + RunOnce entries, reboots. Stage 2 (stepone.ps1): runs in Safe Mode as TrustedInstaller (repoints TrustedInstaller service binPath), modifies Defender settings, reboots. Stage 3 (steptwo.ps1): normal boot, heavy debloat/settings, reboots. |
| bcdedit | Windows inbox | Boot configuration | `bcdedit /set {current} safeboot minimal` forces Safe Mode; `bcdedit /deletevalue {current} safeboot` clears it. Already used by WinSux. |
| RunOnce registry | Windows inbox | Cross-reboot state machine | HKCU RunOnce with `*!` prefix (Safe Mode + deferred deletion) for stage 2; `!` prefix (normal boot, deferred deletion) for stage 3. This is the proven WinSux mechanism. |

### Supporting Libraries

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| Scheduled Tasks (schtasks.exe) | Windows inbox | Alternative/complementary boot trigger | Use ONSTART trigger with `/RU SYSTEM` for stage 2 if RunOnce proves unreliable in Safe Mode. Task Scheduler service runs at boot even in Safe Mode. |
| DWM API (dwmapi.dll) | Windows inbox | Mica backdrop + dark title bar | `DwmSetWindowAttribute(hwnd, 38, ...)` for Mica (Win11 22H2+), `DwmExtendFrameIntoClientArea` for frame extension. Already implemented in AkariTool. |
| System.Drawing | .NET Framework inbox | Wallpaper/lockscreen image generation | WinSux steptwo.ps1 already uses `System.Drawing.Bitmap` to generate black lockscreen/wallpaper images at runtime. |
| System.Windows.Forms | .NET Framework inbox | Screen dimensions for image sizing | `SystemInformation.PrimaryMonitorSize` for generating correctly-sized wallpaper bitmaps. |

### Development Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| Compile.ps1 (AkariTool pattern) | Concatenate scripts + XAML + assets into single .ps1 | AkariTool's Compile.ps1 reads `scripts/start.ps1`, `functions/private/*.ps1`, `functions/public/*.xaml`, embeds XAML panels at `@PANELS@` marker, base64-encodes assets. Directly reusable for AkariOS. |
| Git | Version control | AkariOS repo at `C:/Users/isleap/Documents/GitHub/AkariOS` |
| Notepad++ / VS Code | Editing .ps1 and .xaml files | XAML panels edited as separate files, compiled into single output |

## Installation

```powershell
# AkariOS is a single self-contained .ps1 — no installation required.
# Download and run:
irm https://raw.githubusercontent.com/isleap9/AkariOS/main/akarios.ps1 | iex

# Or run locally:
powershell -NoProfile -ExecutionPolicy Bypass -File .\akarios.ps1
```

## Alternatives Considered

| Recommended | Alternative | When to Use Alternative |
|-------------|-------------|-------------------------|
| RunOnce registry (`*!` / `!` prefix) | Scheduled Tasks ONSTART trigger | If RunOnce fails to fire in Safe Mode on specific builds. Scheduled Tasks with `/RU SYSTEM /sc ONSTART` is more robust but requires Task Scheduler service running in Safe Mode (it does — it's a core service). |
| PowerShell + WPF single-file | C# WPF compiled exe | If XamlReader.Parse proves too limiting for complex UI. C# gives full code-behind, compiled XAML, and better tooling. But loses the "irm \| iex" zero-install distribution model. |
| Console stage 2 (WinSux approach) | WPF GUI in Safe Mode | WPF in Safe Mode is unreliable — BasicDisplay.sys driver + WARP software rendering may work but is undocumented and untested. Console is the safe choice. |
| TrustedInstaller via binPath repoint | Custom Windows service | WinSux's `Run-Trusted` function (stop TrustedInstaller, set binPath to `cmd /c powershell -encodedcommand`, start, restore) is proven. A custom service is more complex and requires install/uninstall. |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| `x:Class` in XAML | `XamlReader.Parse` cannot resolve code-behind; throws `MethodInvocationException` | Use `x:Name` only; wire events in PowerShell via `$sync.FindName()` |
| `x:Name` with `x:` prefix in PowerShell | PowerShell doesn't interpret `x:` prefix; element not found | Strip `x:` prefix or use `Name=` directly in XAML |
| HKLM RunOnce for user-stage tasks | HKLM RunOnce runs at boot before user logon; no user context | Use HKCU RunOnce for per-user stages (stage 2, stage 3) |
| Startup folder shortcuts | Requires user logon; doesn't work in Safe Mode for system tasks | Use RunOnce with `*!` prefix for Safe Mode stages |
| `XamlReader.Parse` without try/catch | Silent failures or cryptic `MethodInvocationException` | Always wrap in try/catch; check for `$null` result; validate XAML with `[xml]` cast first |
| Hardcoded payload URLs in compiled script | WinSux updates payloads independently | Download payloads at runtime from FR33THY's GitHub release URLs (already the WinSux pattern) |

## Stack Patterns by Variant

**If stage 2 must run in Safe Mode as TrustedInstaller:**
- Use HKCU RunOnce with `*!` prefix: `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce\*!stepone`
- The `*` forces execution in Safe Mode; `!` defers deletion until command succeeds
- Value: `powershell.exe -nop -ep bypass -WindowStyle Maximized -f C:\Windows\Temp\stepone.ps1`
- Stage 2 script uses `Run-Trusted` function to repoint TrustedInstaller binPath and execute Defender registry modifications
- After completion, `bcdedit /deletevalue {current} safeboot` clears Safe Mode, then reboots

**If stage 3 must run in normal boot after stage 2:**
- Use HKCU RunOnce with `!` prefix: `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce\!steptwo`
- The `!` defers deletion until command succeeds; no `*` needed (normal boot)
- Stage 3 does heavy debloat, removes Edge/UWP, sets power plan, imports reg.reg, creates restore point, reboots

**If GUI must auto-launch on next boot (normal boot):**
- Stage 3 script (steptwo.ps1) sets a final RunOnce entry: `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce\!AkariOS` → `powershell.exe -nop -ep bypass -WindowStyle Maximized -f C:\Windows\Temp\akarios.ps1`
- This launches the GUI after the final reboot, showing "Step 3 of 3 complete" status
- GUI self-elevates via `Start-Process -Verb RunAs` if not already elevated

**If WPF rendering fails in Safe Mode:**
- Stage 2 is console-only (no WPF) — this is the WinSux design decision
- If GUI must show in Safe Mode: use `Render Tier 0` (software rendering) by setting `RenderOptions.RenderMode = SoftwareOnly` — but this is undocumented and unreliable
- Fallback: show a simple MessageBox or console output instead of full WPF

**If XamlReader.Parse fails:**
- Common causes: `x:Class` attribute, event handler attributes (`Click="..."`), missing `mc:Ignorable="d"` handling
- Detection: wrap in `try { $sync.window = [Windows.Markup.XamlReader]::Parse($inputXML) } catch { [System.Windows.MessageBox]::Show("XAML Error: $_"); exit }`
- Prevention: strip `x:Class`, remove event handler attributes, replace `x:Name` with `Name`, remove `mc:Ignorable` attributes before parsing

## Version Compatibility

| Package A | Compatible With | Notes |
|-----------|-----------------|-------|
| PowerShell 5.1 | Windows 11 22H2/23H2/24H2 | Inbox; no install needed. PowerShell 7.x (pwsh) is NOT recommended — WPF requires .NET Framework, not .NET Core. |
| WPF .NET Framework 4.8 | Windows 11 all builds | Inbox since Win10 1903. `PresentationFramework.dll` available without install. |
| Mica backdrop (DWMWA_SYSTEMBACKDROP_TYPE=38) | Windows 11 22H2+ | Falls back to dark background on Win10 or older Win11. AkariTool already handles this with try/catch. |
| Safe Mode WPF | Windows 11 all builds | BasicDisplay.sys + WARP provides Render Tier 0. WPF may render but is undocumented. Not recommended for production. |
| RunOnce `*!` prefix | Windows 7+ | Documented in Microsoft Learn "RunOnce Registry Key" article. Works in Safe Mode. |
| TrustedInstaller binPath repoint | Windows 7+ | WinSux proven mechanism. Requires admin + TrustedInstaller service stop/start. |

## Sources

- [Microsoft Learn: RunOnce Registry Key](https://learn.microsoft.com/en-us/windows-hardware/drivers/install/runonce-registry-key) — `*` prefix forces Safe Mode execution; `!` prefix defers deletion until success. HIGH confidence.
- [FuzzySecurity: Windows Userland Persistence](https://fuzzysecurity.com/tutorials/19.html) — HKCU vs HKLM RunOnce semantics, Safe Mode behavior. HIGH confidence.
- [JumpSec: Running Once, Running Twice, Pwned!](https://labs.jumpsec.com/running-once-running-twice-pwned-windows-registry-run-keys/) — Exclamation/asterisk prefix behavior. HIGH confidence.
- [Bytejmp: Windows Persistence — Scheduled Tasks](https://bytejmp.com/posts/scheduled-tasks-persistence) — ONSTART trigger with `/RU SYSTEM` runs at boot as SYSTEM. Task Scheduler service starts automatically. HIGH confidence.
- [Microsoft Learn: schtasks create](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/schtasks-create) — ONSTART schedule type documentation. HIGH confidence.
- [Microsoft Learn: OEMInformation](https://learn.microsoft.com/th-th/previous-versions/windows/it-pro/windows-8.1-and-8/ff716332(v=win.10)) — Registry key `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\OEMInformation` with values: Manufacturer, Model, SupportURL, SupportPhone, SupportHours, Logo (BMP path). HIGH confidence.
- [TechBloat: Change OEM Name and Logo](https://www.techbloat.com/how-to-change-oem-name-and-logo-in-windows-10-8-7.html) — Logo should be BMP, ~120x120px. HIGH confidence.
- [NinjaOne: Set Lock Screen Wallpaper](https://www.ninjaone.com/script-hub/set-lock-screen-wallpaper-with-powershell-script/) — `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP` with LockScreenImagePath (REG_SZ), LockScreenImageStatus (DWORD=1), LockScreenImageUrl (REG_SZ). HIGH confidence.
- [Spiceworks: Wallpaper GPO](https://community.spiceworks.com/t/wallpaper-gpo/946328) — Desktop wallpaper via `HKCU\Control Panel\Desktop\Wallpaper` (REG_SZ) + `rundll32 user32.dll,UpdatePerUserSystemParameters`. HIGH confidence.
- [O'Reilly: Changing Network Identity](https://www.oreilly.com/openbook/ntmaint/book/ch07.pdf) — Computer name registry: `HKLM\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName\ComputerName` (pending) and `ActiveComputerName\ComputerName` (active). Reboot required. HIGH confidence.
- [Forenza: Windows Computer Name Registry Key](https://forenza.io/registry-system-computer-name/) — Pending vs active computer name semantics. HIGH confidence.
- [Microsoft Learn: Integrating XAML into PowerShell](https://learn.microsoft.com/en-us/archive/blogs/platformspfe/integrating-xaml-into-powershell) — XamlReader.Load pattern, x:Class removal, error handling. HIGH confidence.
- [PowerShell Gallery: framework.ps1](https://www.powershellgallery.com/packages/XAMLgui/1.1.4/Content/framework.ps1) — XamlReader.Parse error handling, mc:Ignorable stripping, x:Name replacement. HIGH confidence.
- [Microsoft Learn: WPF Graphics Rendering Registry Settings](https://learn.microsoft.com/en-us/dotnet/desktop/WPF/graphics-multimedia/graphics-rendering-registry-settings) — Render tiers, software fallback, DisableHardwareAcceleration option. HIGH confidence.
- [Microsoft Learn: Microsoft Basic Display Driver](https://learn.microsoft.com/en-us/windows-hardware/drivers/display/microsoft-basic-display-driver) — Safe Mode uses BasicDisplay.sys + BasicRender (WARP). WPF Render Tier 0 possible but undocumented. MEDIUM confidence.
- [Microsoft Learn: Self-elevating PowerShell script](https://learn.microsoft.com/en-us/archive/blogs/virtual_pc_guy/a-self-elevating-powershell-script) — `Start-Process -Verb RunAs` pattern. HIGH confidence.
- [AkariTool Compile.ps1](C:/Users/isleap/Documents/GitHub/Akari-Tool/Compile.ps1) — Single-file compilation pattern: concatenate scripts, embed XAML at marker, base64-encode assets. HIGH confidence.
- [AkariTool start.ps1](C:/Users/isleap/Documents/GitHub/Akari-Tool/scripts/start.ps1) — Admin elevation, WPF assembly loading, DWM P/Invoke, synchronized hashtable. HIGH confidence.
- [AkariTool Invoke-RunInBackground.ps1](C:/Users/isleap/Documents/GitHub/Akari-Tool/functions/private/Invoke-RunInBackground.ps1) — Runspace pattern for background operations with DispatcherTimer completion watcher. HIGH confidence.
- [WinSux winsux.ps1](C:/Users/isleap/Documents/GitHub/AkariOS/WinSux-main/WinSux/winsux.ps1) — Stage 1: payload download, RunOnce setup, bcdedit safeboot, reboot. HIGH confidence.
- [WinSux stepone.ps1](C:/Users/isleap/Documents/GitHub/AkariOS/WinSux-main/WinSux/stepone.ps1) — Stage 2: TrustedInstaller Defender modifications, DDU, reboot. HIGH confidence.
- [WinSux steptwo.ps1](C:/Users/isleap/Documents/GitHub/AkariOS/WinSux-main/WinSux/steptwo.ps1) — Stage 3: Edge/UWP removal, power plan, registry import, restore point, reboot. HIGH confidence.

---
*Stack research for: Windows 11 GUI wrapper for multi-reboot system modification engine*
*Researched: 2025-10-04*
