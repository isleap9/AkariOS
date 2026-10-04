# Pitfalls Research

**Domain:** Destructive Windows setup / debloat automation (multi-reboot, Safe Mode, TrustedInstaller)
**Researched:** 2026-10-04
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: RunOnce entries that silently don't fire — wrong hive, wrong user, Safe Mode behavior

**What goes wrong:**
The GUI writes RunOnce entries to `HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce` (as seen in `winsux.ps1` lines 222–225). If the GUI runs as a different user than the one who will log in after reboot, the RunOnce entry is written to the wrong hive and never fires. In Safe Mode, `HKCU` may not load the same way — the default user hive is used, not the logged-in user's. The `*!` prefix (force-run even in Safe Mode) and `!` prefix (delete after running) semantics are also commonly misunderstood: `*!stepone` forces execution in Safe Mode, but if the Safe Mode boot fails to reach the RunOnce stage (e.g., missing Safe Mode drivers), the entry is never consumed and the machine is stranded in Safe Mode with no resume path.

**Why it happens:**
Developers test in a single-user environment where HKCU is always the same hive. They don't account for the GUI running as User A but the post-reboot auto-login being User B, or for Safe Mode loading a different default hive. The `*!` vs `!` prefix distinction is documented only in obscure Windows internals documentation.

**How to avoid:**
- Write RunOnce entries to `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce` instead of `HKCU` — HKLM fires regardless of which user logs in, and is the correct hive for system-level resume.
- Use the `*!` prefix for the Safe Mode stage (stepone) to force execution, and `!` for the normal-boot stage (steptwo) to ensure cleanup.
- After writing RunOnce entries, immediately read them back and verify the command string is intact (no truncation, no missing quotes).
- Add a watchdog: a scheduled task that fires 10 minutes after boot and checks whether the expected stage completed; if not, it re-launches the GUI with a "resume" flag.

**Warning signs:**
- After first reboot, the machine sits at the login screen with no console window appearing.
- `HKCU\...\RunOnce` shows the entry but `HKLM\...\RunOnce` is empty (wrong hive).
- The GUI process is still running pre-reboot but no child `powershell.exe` appears post-reboot.

**Phase to address:** Phase 2 (Core Engine — reboot/resume state machine)

---

### Pitfall 2: Stage reboots before writing its completion marker — state file wiped by disk cleanup

**What goes wrong:**
`steptwo.ps1` runs `cleanmgr.exe /autoclean /d C:\` (line 1203) and deletes `C:\Windows\Temp\*` (line 1188). If the GUI writes its state/progress marker to `%TEMP%` or `C:\Windows\Temp\`, the disk cleanup in the same stage destroys the marker. On the next reboot, the GUI cannot determine which stage completed and either re-runs a destructive stage or does nothing. Similarly, if `steptwo.ps1` reboots (line 1224) before the GUI writes "stage 3 complete" to a persistent location, a power-cycle during the 5-second `Start-Sleep` leaves the system in an ambiguous state.

**Why it happens:**
Developers use `%TEMP%` as a convenient scratch location without realizing that `cleanmgr` and the script's own `Remove-Item` calls target the same directory. The completion marker is written after the reboot trigger, creating a race.

**How to avoid:**
- Write state markers to a location that survives disk cleanup: `C:\ProgramData\AkariOS\state.json` or `HKLM\SOFTWARE\AkariOS\State`.
- Write the completion marker BEFORE calling `shutdown -r`, not after. The marker should say "stage N initiated" so a crash mid-stage is distinguishable from "stage N completed."
- Use a two-phase commit: write "stage N started" → do work → write "stage N completed" → reboot. On resume, check for "completed" markers, not just "started."
- Exclude the state directory from any `Remove-Item` or `cleanmgr` sweeps.

**Warning signs:**
- After stage 3 reboot, the GUI shows "Step 1 of 3" instead of "Step 3 of 3."
- `C:\Windows\Temp\` is empty but the GUI expected a state file there.
- The GUI re-runs a destructive operation that was already completed.

**Phase to address:** Phase 2 (Core Engine — state persistence)

---

### Pitfall 3: UAC prompting mid-flow — the unattended flow becomes a manual flow

**What goes wrong:**
`stepone.ps1` disables UAC (`EnableLUA=0`, line 145) but this only takes effect after a reboot. If the GUI launches `stepone.ps1` before that reboot has occurred, or if any intermediate process triggers a UAC prompt (e.g., `Start-Process -Verb RunAs` in the elevation check), the unattended flow stops at a UAC dialog that no one is watching. In Safe Mode, UAC behaves differently — the built-in Administrator account has UAC disabled by default, but a standard user's token may still trigger prompts for certain operations.

**Why it happens:**
The elevation check in `winsux.ps1` (lines 2–4) and `stepone.ps1` (lines 2–4) uses `Start-Process -Verb RunAs` which always prompts. If the GUI is already elevated but spawns a new PowerShell process without explicitly passing the elevated token, the child process may not inherit elevation.

**How to avoid:**
- Ensure the GUI process is elevated BEFORE launching any stage script, and pass the elevated token to child processes (use `Start-Process -Verb RunAs` only once, at GUI startup).
- After disabling UAC, verify the registry value was written and log it. Do not assume the disable took effect until confirmed.
- In Safe Mode, test whether UAC prompts appear for the specific operations in stepone.ps1 — some `reg add` operations to `HKLM` may still prompt if the token is not fully elevated.
- Add a GUI-level timeout: if a stage script hasn't produced output within N minutes, show a warning and offer to re-launch.

**Warning signs:**
- A UAC dialog appears on screen during an "unattended" run.
- The stage script hangs with no console output.
- `EnableLUA` is still `1` after stepone.ps1 supposedly disabled it.

**Phase to address:** Phase 2 (Core Engine — elevation handling)

---

### Pitfall 4: Power-cycle mid-stage — the machine is left in an unbootable or half-configured state

**What goes wrong:**
If the user power-cycles the machine during `stepone.ps1` (Safe Mode, TrustedInstaller repointing active, Defender partially disabled) or during `steptwo.ps1` (drivers deleted, Edge removed, scheduled tasks wiped), the system may be left in a state where: (a) the TrustedInstaller binPath is still repointed to a base64 encoded command that no longer exists, (b) the safeboot flag is still set, (c) critical services are deleted but not yet re-created, or (b) the BCD store is corrupted. The machine may boot into Safe Mode forever, or boot normally but with no Defender, no Edge, no GPU drivers, and no way to recover.

**Why it happens:**
The scripts have no transactional guarantees. Each `reg add`, `sc delete`, `Remove-Item` is immediately committed. There is no journal or rollback. A power-cycle at the wrong moment leaves the system in an inconsistent state.

**How to avoid:**
- Before any destructive operation, create a system restore point AND export the current BCD store (`bcdedit /export C:\BCD-backup.reg`) and critical registry hives.
- Write a "recovery script" to `C:\ProgramData\AkariOS\recover.ps1` that can: restore the TrustedInstaller binPath, remove the safeboot flag, re-enable Defender, and re-create deleted scheduled tasks. The GUI should detect a "crashed mid-stage" state on resume and offer to run recovery.
- Use `bcdedit /deletevalue {current} safeboot` as the FIRST operation in stepone.ps1 (before any destructive changes), so a power-cycle after that point at least boots normally.
- Add a BIOS/UEFI-level watchdog if possible: if the machine doesn't check in within N minutes, boot into a recovery partition.

**Warning signs:**
- After a power-cycle, the machine boots into Safe Mode with no GUI.
- `bcdedit /enum {current}` shows `safeboot` still set.
- `Get-Service TrustedInstaller` shows a binPath pointing to `cmd.exe /c powershell.exe -encodedcommand ...`.

**Phase to address:** Phase 2 (Core Engine — crash recovery) and Phase 4 (Testing — power-cycle simulation)

---

### Pitfall 5: Safe Mode breaks networking — downloads fail, GUI can't phone home

**What goes wrong:**
`stepone.ps1` runs in Safe Mode. Safe Mode with Networking loads only basic drivers — no GPU, no audio, potentially no Wi-Fi (depending on the driver). If the GUI or stepone.ps1 needs to download anything (e.g., a payload that wasn't pre-staged in stage 1), the download will fail silently. The `IWR` calls in `winsux.ps1` (stage 1, normal mode) are fine, but any network dependency in stage 2 is a liability. Additionally, WPF may not render correctly in Safe Mode — the .NET Framework's WPF relies on DirectX which may not be available without GPU drivers.

**Why it happens:**
Developers assume "Safe Mode with Networking" means "full network access." In practice, many Wi-Fi drivers are third-party and don't load in Safe Mode. WPF's rendering pipeline also depends on `dwmapi.dll` and DirectX components that may be degraded.

**How to avoid:**
- Pre-download ALL payloads in stage 1 (normal mode) to `C:\ProgramData\AkariOS\payloads\`. Stage 2 should have zero network dependencies.
- In Safe Mode, use a console-only UI (no WPF). The current design already does this (stepone.ps1 is a console script), which is correct.
- Test Safe Mode networking explicitly: boot a VM into Safe Mode with Networking and verify `Test-Connection` works.
- Add a fallback: if a download fails in stage 2, log the failure and continue with a warning rather than silently skipping.

**Warning signs:**
- `IWR` in Safe Mode returns `Unable to connect to the remote server`.
- The GUI window doesn't appear in Safe Mode (WPF rendering failure).
- `Test-Connection 8.8.8.8` fails in Safe Mode but succeeds in normal mode.

**Phase to address:** Phase 1 (Foundation — payload pre-staging) and Phase 4 (Testing — Safe Mode validation)

---

### Pitfall 6: TrustedInstaller binPath repointing fails or isn't restored — the machine is bricked

**What goes wrong:**
The `Run-Trusted` function in `stepone.ps1` (lines 12–36) repoints the TrustedInstaller service binPath to `cmd.exe /c powershell.exe -encodedcommand <base64>`. If the `sc.exe config` command fails (e.g., because the service is locked, or the base64 string is malformed), the TrustedInstaller service is left with a broken binPath. On the next boot, Windows cannot start TrustedInstaller, which means Windows Update fails, Windows Installer fails, and many system operations fail. If the `sc.exe config TrustedInstaller binpath= "$DefaultBinPath"` restore command (line 29) fails or is skipped (e.g., because the script crashes between lines 27 and 29), the repointing is permanent. This is a brick.

**Why it happens:**
The repointing trick is inherently fragile — it modifies a critical system service's binary path. There is no transaction. If the encoded command is too long, contains special characters, or if `sc.exe` is blocked by Defender (which is being disabled in the same script), the operation fails silently. The `Stop-Service -Force` at line 14 may also fail if TrustedInstaller is in a weird state.

**How to avoid:**
- Before repointing, export the current binPath to a file: `Get-CimInstance Win32_Service -Filter "Name='TrustedInstaller'" | Select-Object -ExpandProperty PathName | Out-File C:\TI-path.txt`.
- After the TrustedInstaller command completes, verify the binPath was restored: `Get-CimInstance Win32_Service -Filter "Name='TrustedInstaller'" | Select-Object PathName` should match the original.
- Add a watchdog: a scheduled task that fires 5 minutes after boot and checks the TrustedInstaller binPath; if it's not the default, it restores it.
- Consider using `PsExec -s` or `schtasks /run /ru SYSTEM` as alternatives to the binPath repointing trick — they are less fragile.
- Test the repointing in a VM first and verify the restore works.

**Warning signs:**
- `Get-Service TrustedInstaller` shows `Status: Stopped` and won't start.
- `sc qc TrustedInstaller` shows a binPath containing `encodedcommand`.
- Windows Update fails with error `0x80070005` (access denied) after stepone.

**Phase to address:** Phase 2 (Core Engine — TrustedInstaller handling) and Phase 4 (Testing — repoint/restore validation)

---

### Pitfall 7: DDU in Safe Mode behaves differently — drivers not fully removed, or DDU crashes

**What goes wrong:**
`stepone.ps1` runs DDU with `-CleanSoundBlaster -CleanRealtek -CleanAllGpus -Restart` (line 153). DDU is designed to run in Safe Mode, but its behavior varies: in Safe Mode, some driver stores may be locked, DDU may not be able to remove all driver packages, and the `-Restart` flag may not work correctly if the safeboot flag is still set (DDU may try to set its own safeboot flag, conflicting with the existing one). Additionally, DDU's `-CleanAllGpus` removes ALL GPU drivers — if the machine has an NVIDIA GPU and DDU removes the driver but Windows Basic Display Adapter doesn't load in Safe Mode, the next boot may have no display output.

**Why it happens:**
DDU's Safe Mode support is best-effort. It relies on the same TrustedInstaller and service-control APIs that may be in a weird state during stepone. The `-Restart` flag calls `shutdown -r` internally, which may conflict with the script's own reboot logic.

**How to avoid:**
- Run DDU with explicit logging: add `-LogPath C:\DDU-log.txt` so you can diagnose what it actually did.
- After DDU completes, verify the GPU driver state: `Get-PnpDevice -Class Display` should show `Microsoft Basic Display Adapter` or similar.
- Do NOT rely on DDU's `-Restart` — let the script control the reboot. Remove `-Restart` from the DDU arguments and call `shutdown -r` explicitly after DDU exits.
- Test DDU in a VM with Safe Mode and verify the display adapter state after reboot.

**Warning signs:**
- After DDU + reboot, the display is stuck at 640×480 or shows "No Signal."
- `Get-PnpDevice -Class Display` shows the old GPU driver still present.
- DDU log shows "Access denied" or "Service not found" errors.

**Phase to address:** Phase 2 (Core Engine — DDU integration) and Phase 4 (Testing — DDU in Safe Mode)

---

### Pitfall 8: Deleting all non-Microsoft scheduled tasks — breaks Defender, Update, and other critical services

**What goes wrong:**
`steptwo.ps1` lines 345–353 delete all scheduled tasks under `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Tree` that are not named "Microsoft", and all files under `C:\Windows\System32\Tasks` that are not named "Microsoft". This is catastrophically broad: it deletes tasks owned by third-party software (good) but also tasks that happen to not be under a "Microsoft" folder (bad). Some Microsoft tasks are registered under custom paths. Additionally, deleting the TaskCache tree while the Task Scheduler service is running can cause the service to crash or hang. The `Run-Trusted` call (line 347) uses the TrustedInstaller repointing trick, which may fail if TrustedInstaller is in a bad state.

**Why it happens:**
The filter `$_.PSChildName -ne "Microsoft"` is too simplistic. It assumes all Microsoft tasks are under a folder named "Microsoft", which is not always true. The script also doesn't check whether a task is a critical system task before deleting it.

**How to avoid:**
- Use a blocklist approach instead of an allowlist: delete only tasks matching known third-party patterns (e.g., `*NVIDIA*`, `*AMD*`, `*Intel*`, `*Dropbox*`, `*GoogleUpdate*`).
- Before deleting, export the task list: `Get-ScheduledTask | Export-Csv C:\tasks-backup.csv`.
- Stop the Task Scheduler service before deleting tasks, then restart it after.
- Add a verification step: after deletion, check that critical Microsoft tasks (e.g., `\Microsoft\Windows\Defender\*`) still exist.

**Warning signs:**
- After steptwo, Windows Update fails with "Service not available."
- `Get-ScheduledTask` shows zero tasks under `\Microsoft\Windows\Defender\`.
- The Task Scheduler service fails to start.

**Phase to address:** Phase 3 (Integration — task deletion logic) and Phase 4 (Testing — post-deletion validation)

---

### Pitfall 9: Forcing Edge uninstall — breaks WebView2, Store, and other Edge-dependent components

**What goes wrong:**
`steptwo.ps1` lines 41–124 force-remove Microsoft Edge by: stopping Edge processes, deleting EdgeUpdate registry keys, creating a dummy `MicrosoftEdge.exe` in SystemApps, finding the Edge uninstall string and appending `--force-uninstall`, deleting the `C:\Program Files (x86)\Microsoft` folder, and removing Edge services. This breaks: (a) Edge WebView2 (used by many apps including Discord, Teams, and the AkariTool GUI itself if it uses WebView2), (b) the Microsoft Store (which depends on Edge components), (c) Windows Widgets, and (d) any app that uses the Edge rendering engine. The `--force-uninstall` flag is also not officially documented and may behave differently across Edge versions.

**Why it happens:**
Edge is deeply integrated into Windows 11. The "force uninstall" approach is a hack that works by tricking the Edge installer into removing itself, but it doesn't account for all the dependencies. The `Remove-Item -Recurse -Force "C:\Program Files (x86)\Microsoft"` (line 107) is especially dangerous — it deletes the entire Microsoft folder, not just Edge.

**How to avoid:**
- Do NOT delete `C:\Program Files (x86)\Microsoft` — target only `C:\Program Files (x86)\Microsoft\Edge` and `C:\Program Files (x86)\Microsoft\EdgeUpdate`.
- Before removing Edge, check if WebView2 is installed and warn the user that apps depending on it will break.
- Use the official Edge removal method: `MsiExec.exe /X {ProductCode} /qn` for the Edge MSI, or use `Remove-WindowsPackage` for the Edge AppX package.
- After Edge removal, verify that `Get-AppxPackage *MicrosoftEdge*` returns nothing and that `C:\Program Files (x86)\Microsoft\Edge` is gone.

**Warning signs:**
- After steptwo, apps using WebView2 fail to launch.
- `Get-AppxPackage *MicrosoftEdge*` still shows Edge installed.
- The Microsoft Store fails to open.

**Phase to address:** Phase 3 (Integration — Edge removal) and Phase 4 (Testing — post-removal app compatibility)

---

### Pitfall 10: `bcdedit safeboot` left set — the machine boots into Safe Mode forever

**What goes wrong:**
`winsux.ps1` line 228 sets `bcdedit /set {current} safeboot minimal`. `stepone.ps1` line 148 removes it with `bcdedit /deletevalue {current} safeboot`. If stepone.ps1 crashes before line 148, or if the `bcdedit /deletevalue` command fails (e.g., because the BCD store is locked or corrupted), the machine boots into Safe Mode on every subsequent boot. The user sees a Safe Mode desktop with no GUI, no network, and no obvious way to fix it. This is a soft-brick.

**Why it happens:**
The safeboot flag is set in stage 1 and cleared in stage 2. If stage 2 doesn't run (RunOnce failure, Safe Mode boot failure, TrustedInstaller repointing failure), the flag is never cleared. There is no timeout or fallback.

**How to avoid:**
- Add a boot-count watchdog: write a registry value `HKLM\SOFTWARE\AkariOS\BootCount` that increments on each boot. If it exceeds 3, automatically clear the safeboot flag and boot normally.
- In the GUI, before setting safeboot, export the BCD store: `bcdedit /export C:\BCD-backup.reg`. If the GUI detects a "stuck in Safe Mode" state on resume, it can restore the BCD.
- Add a `bcdedit /deletevalue {current} safeboot` call at the START of stepone.ps1 (before any destructive operations), so even if the script crashes later, the machine will boot normally next time.
- Test: set safeboot, reboot, verify the machine enters Safe Mode, then clear safeboot and verify it boots normally.

**Warning signs:**
- The machine boots into Safe Mode with "Safe Mode" watermarks on all four corners.
- `bcdedit /enum {current}` shows `safeboot` set to `Minimal`.
- The GUI doesn't appear in Safe Mode (because it's a WPF app that needs GPU drivers).

**Phase to address:** Phase 2 (Core Engine — safeboot management) and Phase 4 (Testing — safeboot/clear-safeboot cycle)

---

### Pitfall 11: Disabling UAC + Defender + tamper protection — the user is left with zero security

**What goes wrong:**
`stepone.ps1` disables: real-time monitoring, tamper protection, SmartScreen, controlled folder access, PUA protection, memory integrity (HVCI), VBS/hypervisor launch, LSA protection (RunAsPPL), the vulnerable driver blocklist, and UAC (`EnableLUA=0`). This leaves the machine completely exposed to malware, ransomware, and privilege escalation. If the user doesn't re-enable these after the setup (and the script doesn't re-enable them), they have a fast but insecure machine. Additionally, Windows may automatically re-enable some of these settings on reboot or after a Windows Update, causing confusion.

**Why it happens:**
The script's goal is maximum performance and minimum interference, which means disabling all security features. But there is no "setup complete" phase that re-enables the features the user actually wants (e.g., firewall, but not controlled folder access).

**How to avoid:**
- Add a "post-setup security configuration" phase that lets the user choose which security features to re-enable.
- At minimum, re-enable the firewall and Windows Update after setup completes.
- Document clearly which features are disabled and how to re-enable them.
- Add a GUI warning: "Your system has no real-time malware protection. Re-enable Defender after setup."
- Consider keeping tamper protection enabled — it prevents malware from re-enabling Defender, but also prevents the script from disabling it. The script already handles this by running as TrustedInstaller.

**Warning signs:**
- After setup, `Get-MpPreference` shows `DisableRealtimeMonitoring: True` and `DisableTamperProtection: True`.
- Windows Security app shows multiple red warnings.
- The user reports malware infection after setup.

**Phase to address:** Phase 3 (Integration — security configuration) and Phase 5 (Distribution — user documentation)

---

### Pitfall 12: BitLocker disable on an encrypted drive — data loss or boot failure

**What goes wrong:**
`steptwo.ps1` lines 437–445 disable BitLocker on all volumes where `ProtectionStatus -eq "On"` or `VolumeStatus -ne "FullyDecrypted"`. If the drive is currently encrypted and the disable operation fails (e.g., because the TPM is in a weird state, or the recovery key is not available), the drive may be left in a partially decrypted state. On some systems, disabling BitLocker triggers a reboot, which conflicts with the script's own reboot logic. If the drive is the system drive and BitLocker is disabled without fully decrypting it, the next boot may fail.

**Why it happens:**
The script assumes `Disable-BitLocker` is a simple, instantaneous operation. In reality, it can take hours on a large drive and may require a reboot. The `-ErrorAction SilentlyContinue` (line 443) swallows any errors, so failures are invisible.

**How to avoid:**
- Before disabling BitLocker, check if the drive is fully decrypted: `Get-BitLockerVolume | Select-Object VolumeStatus`. If not, warn the user and skip.
- Do NOT disable BitLocker on the system drive — only on data drives.
- Log the BitLocker status before and after the operation.
- Remove `-ErrorAction SilentlyContinue` and handle errors explicitly.
- Add a GUI prompt: "BitLocker is enabled on C:. Disabling it may take hours and requires a reboot. Continue?"

**Warning signs:**
- After steptwo, the system asks for a BitLocker recovery key on boot.
- `Get-BitLockerVolume` shows `VolumeStatus: DecryptionInProgress`.
- The system fails to boot with a BitLocker error screen.

**Phase to address:** Phase 3 (Integration — BitLocker handling) and Phase 4 (Testing — BitLocker scenarios)

---

### Pitfall 13: Pausing Windows Update for 365 days — the machine misses critical security patches

**What goes wrong:**
`steptwo.ps1` lines 476–485 pause Windows Update for 365 days by setting `PauseUpdatesExpiryTime`, `PauseFeatureUpdatesEndTime`, `PauseQualityUpdatesEndTime`, etc. This means the machine receives zero security patches for a year. Combined with disabled Defender, this is a massive security risk. Additionally, the pause may be overridden by Windows Update itself (e.g., for critical updates), or by a Windows Update reset after a feature update.

**Why it happens:**
The script assumes the user wants zero updates for maximum stability. But 365 days is too long — critical security patches (e.g., for zero-day exploits) should still be installed.

**How to avoid:**
- Reduce the pause to 30 days (the maximum allowed by Windows Update policies) instead of 365.
- Add a GUI option: "Pause updates for [30/60/90/365] days."
- After the pause expires, notify the user and offer to resume updates.
- Document the security implications of pausing updates.

**Warning signs:**
- After 30 days, the machine still has not received any updates.
- `Get-WindowsUpdateLog` shows no update activity.
- The user reports a malware infection that a security patch would have prevented.

**Phase to address:** Phase 3 (Integration — Windows Update configuration) and Phase 5 (Distribution — user documentation)

---

### Pitfall 14: `dism /Remove-Package` on Edge legacy package — servicing stack corruption

**What goes wrong:**
`steptwo.ps1` lines 117–124 remove the Edge legacy package using `dism /online /Remove-Package /PackageName:$EdgeLegacyPackage`. If the package name is incorrect, or if the package is a dependency of another component, DISM may fail or corrupt the servicing stack. A corrupted servicing stack means future Windows Updates fail, and the machine cannot install or remove any packages. The `2>$null` on line 123 suppresses all errors, so failures are invisible.

**Why it happens:**
The script assumes the Edge legacy package exists and can be safely removed. On Windows 11, the Edge legacy package may not exist (it's a Windows 10 component), or it may be a dependency of the Edge WebView2 runtime.

**How to avoid:**
- Check if the package exists before attempting removal: `Get-WindowsPackage -Online | Where-Object {$_.PackageName -like "*Internet-Browser*"}`.
- Do NOT suppress DISM errors — log them and handle them explicitly.
- After DISM removal, verify the servicing stack is healthy: `dism /online /cleanup-image /scanhealth`.
- Consider using `Remove-WindowsPackage` instead of `dism /online /Remove-Package` — it has better error handling.

**Warning signs:**
- After steptwo, Windows Update fails with error `0x800f081f` (source file not found).
- `dism /online /cleanup-image /scanhealth` reports corruption.
- The Edge legacy package is still installed.

**Phase to address:** Phase 3 (Integration — DISM operations) and Phase 4 (Testing — servicing stack health)

---

### Pitfall 15: IWR from GitHub release URLs — rate limits, TLS, redirects, silent partial downloads

**What goes wrong:**
`winsux.ps1` uses `IWR` (Invoke-WebRequest) to download payloads from GitHub release URLs (e.g., `https://github.com/FR33THYFR33THY/WinSux/releases/download/Files/7zip.exe`). GitHub release downloads are redirected to `objects.githubusercontent.com`, which may rate-limit unauthenticated requests. If the download is interrupted (network drop, DNS failure), `IWR` may leave a partial file that is silently used as if it were complete. There is no hash verification — a corrupted or tampered payload is installed without detection. Additionally, if FR33THY moves or renames the release asset, the URL returns a 404 and `IWR` throws an error that may not be caught.

**Why it happens:**
`IWR` is a simple cmdlet that doesn't handle retries, resume, or hash verification. GitHub's rate limits (60 requests/hour for unauthenticated API requests) are easily hit if the script is run multiple times. The `IWR` calls in `winsux.ps1` have no error handling — a failed download causes the script to fail at that point, but the error message may be unclear.

**How to avoid:**
- Add hash verification: compute the SHA-256 of each downloaded file and compare it to a known-good hash before installation.
- Use `Invoke-WebRequest -Resume` or `curl.exe` with `--retry` for resilient downloads.
- Add error handling around each `IWR` call: `try { IWR ... } catch { Write-Host "Download failed: $_"; exit 1 }`.
- Cache downloaded payloads in `C:\ProgramData\AkariOS\payloads\` and skip re-downloading if the file already exists and matches the hash.
- Consider mirroring the payloads on a CDN or Azure Blob Storage to avoid GitHub rate limits.

**Warning signs:**
- `IWR` returns a 404 or 403 error.
- The downloaded file is 0 bytes or significantly smaller than expected.
- The installer fails with "corrupt file" or "invalid signature."
- GitHub API rate limit exceeded (error 403 with "rate limit" in the message).

**Phase to address:** Phase 1 (Foundation — download infrastructure) and Phase 4 (Testing — download failure scenarios)

---

### Pitfall 16: 7-Zip installed and then used to extract other payloads in the same stage — ordering dependency

**What goes wrong:**
`winsux.ps1` installs 7-Zip (line 38) and then immediately uses it to extract DDU (line 86) and DirectX (line 178). If the 7-Zip installation fails or is delayed (e.g., UAC prompt, antivirus blocking), the `7z.exe` calls fail silently (`| Out-Null` on line 86). The script continues as if the extraction succeeded, and DDU/DirectX are never installed. This is a silent failure — the script doesn't check whether `7z.exe` exists before calling it.

**Why it happens:**
The script assumes 7-Zip installation is instantaneous and always succeeds. In practice, 7-Zip's `/S` silent install may fail if another installer is running, or if the system is locked down.

**How to avoid:**
- After installing 7-Zip, verify it exists: `if (!(Test-Path "C:\Program Files\7-Zip\7z.exe")) { Write-Host "7-Zip installation failed"; exit 1 }`.
- Add a retry loop for the 7-Zip installation.
- Check the exit code of each `Start-Process -Wait` call.
- Consider using `System.IO.Compression` or `Expand-Archive` (for ZIP files) as a fallback if 7-Zip is not available.

**Warning signs:**
- `Test-Path "C:\Program Files\7-Zip\7z.exe"` returns `False` after stage 1.
- DDU or DirectX is not installed after stage 1.
- The script continues without error but the payloads are missing.

**Phase to address:** Phase 1 (Foundation — 7-Zip dependency) and Phase 4 (Testing — 7-Zip installation failure)

---

### Pitfall 17: Antivirus flagging the script — SmartScreen, Defender, and third-party AV

**What goes wrong:**
The WinSux scripts are flagged by Defender, SmartScreen, and third-party antivirus as malware or a potentially unwanted application (PUA). This is because the scripts: disable Defender, disable tamper protection, modify the TrustedInstaller service, delete scheduled tasks, and remove Edge — all behaviors that match malware signatures. Windows SmartScreen may block the script from running, and Defender may quarantine the downloaded payloads. This is especially problematic because the script disables Defender in stage 2, but Defender may block the script in stage 1 before it gets a chance to disable anything.

**Why it happens:**
The scripts exhibit every behavior that antivirus software is designed to detect and block. There is no code signing, no whitelisting, and no official distribution channel.

**How to avoid:**
- Sign the GUI and scripts with an Extended Validation (EV) code-signing certificate to avoid SmartScreen warnings.
- Add the GUI and scripts to the Defender allowlist before running (requires admin).
- Distribute the GUI through the Microsoft Store or a trusted website with a good reputation.
- Add a GUI warning: "Your antivirus may flag this tool. Add it to the allowlist before running."
- Consider submitting the tool to antivirus vendors for whitelisting.

**Warning signs:**
- Windows SmartScreen shows "Windows protected your PC" when launching the GUI.
- Defender quarantines `winsux.ps1` or the downloaded payloads.
- Third-party AV (e.g., Malwarebytes, Norton) shows a detection alert.

**Phase to address:** Phase 5 (Distribution — code signing and AV whitelisting)

---

### Pitfall 18: Script fetched and piped to `iex` — corrupted or tampered copy

**What goes wrong:**
If users run the script via `irm <url> | iex` (Invoke-Expression), the script is fetched from the internet and executed directly in memory. If the download is interrupted, the script is truncated and may execute partially. If the URL is compromised (e.g., GitHub account hijack, MITM attack), a malicious version of the script is executed. There is no integrity check — the user has no way to verify that the script they're running is the one the developer published.

**Why it happens:**
The `irm | iex` pattern is convenient but inherently insecure. It bypasses all file-based security checks (SmartScreen, antivirus scanning, hash verification). The AkariTool's `start.ps1` already handles this case (lines 9–12) by re-fetching and running elevated, but the WinSux scripts do not.

**How to avoid:**
- Distribute the GUI as a compiled executable (WPF app), not a script.
- If scripts must be used, sign them and verify the signature before execution.
- Add a hash verification step: after downloading, compute the SHA-256 and compare it to a known-good hash embedded in the GUI.
- Encourage users to download the GUI from the official website, not via `irm | iex`.
- Add a GUI-level integrity check: before running any stage, verify that the script files on disk match expected hashes.

**Warning signs:**
- The script behaves differently than expected (e.g., deletes files it shouldn't).
- The script contains code that the developer didn't write.
- Antivirus flags the script as suspicious.

**Phase to address:** Phase 5 (Distribution — secure distribution and integrity verification)

---

### Pitfall 19: Testing a multi-reboot destructive flow — no safe way to validate

**What goes wrong:**
The WinSux flow reboots the machine twice, wipes drivers, disables security, and deletes system components. Testing this on a physical machine is destructive and time-consuming. Developers may skip testing entirely, or test only on their own machine and assume it works everywhere. Without proper testing, edge cases (e.g., different hardware, different Windows versions, different update states) are not discovered until users report them.

**Why it happens:**
The flow is inherently destructive and hard to automate. Each test run takes 30+ minutes (two reboots, driver installation, etc.). There is no "dry-run" mode.

**How to avoid:**
- Use Hyper-V or VMware VMs with snapshots for testing. Take a snapshot before each stage and roll back if something goes wrong.
- Add a `--dry-run` mode to the scripts that logs what they would do without actually doing it.
- Test on multiple Windows versions (Windows 10 22H2, Windows 11 23H2, Windows 11 24H2) and multiple hardware configurations (NVIDIA, AMD, Intel GPUs).
- Add automated validation: after each stage, run a validation script that checks the expected state (e.g., "Defender is disabled," "Edge is removed," "GPU driver is gone").
- Test power-cycle scenarios: kill the VM mid-stage and verify recovery works.

**Warning signs:**
- The script works on the developer's machine but fails on a user's machine.
- A stage silently does nothing (e.g., DDU doesn't remove the driver).
- The machine is left in an unbootable state after testing.

**Phase to address:** Phase 4 (Testing — VM-based testing and dry-run mode)

---

### Pitfall 20: State file wiped by disk cleanup — the GUI loses track of progress

**What goes wrong:**
`steptwo.ps1` runs `cleanmgr.exe /autoclean /d C:\` (line 1203) which deletes temporary files, including any state file the GUI wrote to `%TEMP%` or `C:\Windows\Temp\`. If the GUI writes its progress state (e.g., "stage 2 of 3 complete") to a temp file, the disk cleanup destroys it. On the next reboot, the GUI cannot determine which stage completed and either re-runs a destructive stage or does nothing.

**Why it happens:**
Developers use `%TEMP%` as a convenient scratch location without realizing that `cleanmgr` and the script's own `Remove-Item` calls target the same directory.

**How to avoid:**
- Write state markers to `C:\ProgramData\AkariOS\state.json` or `HKLM\SOFTWARE\AkariOS\State` — locations that survive disk cleanup.
- Write the completion marker BEFORE calling `shutdown -r`, not after.
- Use a two-phase commit: "stage N started" → do work → "stage N completed" → reboot.
- On resume, check for "completed" markers, not just "started."

**Warning signs:**
- After stage 3 reboot, the GUI shows "Step 1 of 3" instead of "Step 3 of 3."
- The GUI re-runs a destructive operation that was already completed.
- `C:\Windows\Temp\` is empty but the GUI expected a state file there.

**Phase to address:** Phase 2 (Core Engine — state persistence)

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Using `%TEMP%` for state files | No need to create a dedicated directory | State files wiped by disk cleanup; GUI loses progress | Never — use `C:\ProgramData\` or registry |
| Suppressing all errors with `-ErrorAction SilentlyContinue` | Script doesn't stop on minor errors | Critical failures are invisible; hard to debug | Only for truly optional operations (e.g., removing a shortcut that may not exist) |
| Hardcoded URLs for payloads | No need for a URL management system | URLs break when assets are moved/renamed; no fallback | Never — use a manifest file with hashes and fallback URLs |
| Running DDU with `-Restart` flag | One less line of code | DDU's reboot may conflict with the script's reboot logic | Never — let the script control the reboot |
| Deleting `C:\Program Files (x86)\Microsoft` entirely | Guarantees Edge is removed | Breaks WebView2, Store, and other Edge-dependent components | Never — target only Edge-specific subdirectories |
| Using `irm \| iex` for distribution | No installation required | No integrity check; vulnerable to truncation and MITM | Never for a compiled GUI; acceptable for a bootstrapper with hash verification |
| No hash verification on downloaded payloads | Faster downloads | Corrupted or tampered payloads installed silently | Never — always verify SHA-256 before installation |
| Single-user testing only | Faster test cycles | Edge cases on other hardware/Windows versions cause failures | Only for initial prototyping; never for release |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| GitHub Release URLs | Assuming URLs are permanent; no handling for 404/403 | Use a manifest file with hashes; add retry logic; cache payloads locally |
| TrustedInstaller service | Repointing binPath without verifying restore | Export original binPath first; verify restore after; add watchdog scheduled task |
| DDU | Assuming DDU works identically in Safe Mode | Test in Safe Mode explicitly; add logging; verify driver state post-DDU |
| Windows Update pause | Pausing for 365 days without user consent | Make pause duration configurable; default to 30 days; notify user on expiry |
| BitLocker | Disabling without checking decryption state | Check `VolumeStatus` first; warn user; skip system drive |
| Edge removal | Deleting entire `C:\Program Files (x86)\Microsoft` folder | Target only Edge-specific subdirectories; check WebView2 dependencies |
| Scheduled tasks | Deleting all non-Microsoft tasks | Use blocklist approach; export task list first; verify critical tasks survive |
| `dism /Remove-Package` | Suppressing errors with `2>$null` | Log errors explicitly; verify servicing stack health after |
| WPF in Safe Mode | Assuming WPF renders correctly in Safe Mode | Use console-only UI in Safe Mode; test WPF rendering in Safe Mode VM |
| `IWR` downloads | No retry, no resume, no hash verification | Use `curl.exe --retry` or `Invoke-WebRequest -Resume`; verify SHA-256 |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Running DDU on all GPUs | Display output lost after reboot | Verify GPU state after DDU; keep a basic display driver fallback | Machines with NVIDIA Optimus or switchable graphics |
| Deleting all scheduled tasks | Windows Update and Defender stop working | Use blocklist approach; verify critical tasks survive | Any machine with non-standard task registration |
| Disabling memory compression | Increased disk I/O, slower performance | Document the tradeoff; make it optional | Machines with low RAM (< 8GB) |
| Disabling UAC | No elevation prompts; malware runs silently | Re-enable after setup; add GUI warning | Any machine that installs third-party software |
| Pausing Windows Update for 365 days | Zero security patches for a year | Reduce to 30 days; notify user on expiry | Any machine connected to the internet |
| Deleting `Windows.old` | Cannot roll back to previous Windows version | Warn user; keep for 30 days after setup | Any machine that may need to roll back |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Disabling Defender + tamper protection + UAC | Machine is completely exposed to malware | Add a post-setup security configuration phase; re-enable firewall at minimum |
| Running as TrustedInstaller via binPath repointing | If not restored, Windows Update and Installer break permanently | Verify restore after each operation; add watchdog scheduled task |
| No hash verification on payloads | Corrupted or tampered payloads installed silently | Compute and verify SHA-256 before installation |
| Distributing via `irm \| iex` | No integrity check; vulnerable to truncation and MITM | Distribute as compiled executable; verify signature |
| No code signing | SmartScreen and antivirus flag the tool | Sign with EV code-signing certificate; submit to AV vendors for whitelisting |
| Disabling vulnerable driver blocklist | Malicious drivers can be loaded | Document the risk; make it optional; re-enable after setup |
| Disabling LSA protection (RunAsPPL) | Credential theft via LSASS | Document the risk; make it optional; re-enable after setup |
| Disabling memory integrity (HVCI) | Kernel-level malware can run | Document the risk; make it optional; re-enable after setup |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| No progress indicator during long stages | User thinks the app is frozen; force-kills it | Show a progress bar with stage name and elapsed time |
| No warning before destructive operations | User accidentally wipes their machine | Require typed acknowledgment + restore point before each stage |
| No way to cancel mid-stage | User is committed once they start | Add a "Cancel" button that stops the current operation and offers recovery |
| No post-setup summary | User doesn't know what was changed | Show a summary screen with all changes made and how to reverse them |
| No way to re-enable disabled security features | User doesn't know Defender is disabled | Add a "Security" panel that shows which features are disabled and offers to re-enable them |
| Assuming the user knows what Safe Mode is | User panics when they see Safe Mode desktop | Show a pre-reboot warning: "Your PC will reboot into Safe Mode. This is normal." |
| No recovery option if something goes wrong | User is stuck with a broken machine | Add a "Recovery" mode that can restore TrustedInstaller, clear safeboot, and re-enable Defender |
| GUI doesn't show which step is running | User doesn't know if the flow is progressing | Show "Step N of 3" prominently with a description of what's happening |

## "Looks Done But Isn't Checklist"

- [ ] **RunOnce entries:** Often missing verification that the entry was written correctly — verify by reading back the registry value and checking the command string is intact
- [ ] **State persistence:** Often missing a write-before-reboot pattern — verify the completion marker is written BEFORE `shutdown -r`, not after
- [ ] **TrustedInstaller restore:** Often missing verification that the binPath was restored — verify with `sc qc TrustedInstaller` after each `Run-Trusted` call
- [ ] **Safe Mode boot:** Often missing a test that the machine actually enters Safe Mode — verify with `bcdedit /enum {current}` showing `safeboot` set
- [ ] **DDU driver removal:** Often missing verification that the GPU driver was actually removed — verify with `Get-PnpDevice -Class Display` showing `Microsoft Basic Display Adapter`
- [ ] **Edge removal:** Often missing verification that Edge is actually gone — verify with `Get-AppxPackage *MicrosoftEdge*` returning nothing
- [ ] **Scheduled task deletion:** Often missing verification that critical Microsoft tasks survived — verify with `Get-ScheduledTask` showing Defender and Update tasks
- [ ] **BitLocker disable:** Often missing verification that the drive is fully decrypted — verify with `Get-BitLockerVolume` showing `FullyDecrypted`
- [ ] **Payload downloads:** Often missing hash verification — verify SHA-256 of each downloaded file before installation
- [ ] **7-Zip dependency:** Often missing verification that 7-Zip was installed before calling `7z.exe` — verify with `Test-Path "C:\Program Files\7-Zip\7z.exe"`
- [ ] **Defender disable:** Often missing verification that Defender is actually disabled — verify with `Get-MpPreference` showing `DisableRealtimeMonitoring: True`
- [ ] **UAC disable:** Often missing verification that UAC is actually disabled — verify with `Get-ItemProperty` showing `EnableLUA: 0`
- [ ] **Windows Update pause:** Often missing verification that the pause was applied — verify with `Get-ItemProperty` showing `PauseUpdatesExpiryTime` set
- [ ] **Power-cycle recovery:** Often missing a recovery script — verify that `C:\ProgramData\AkariOS\recover.ps1` exists and can restore critical settings
- [ ] **GUI resume across reboots:** Often missing a test that the GUI actually resumes after reboot — verify that the GUI launches automatically and shows the correct step

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| RunOnce doesn't fire | MEDIUM | Boot into Safe Mode with Command Prompt, manually run `powershell.exe -nop -ep bypass -File C:\Windows\Temp\stepone.ps1` |
| TrustedInstaller binPath not restored | HIGH | Boot into WinRE, load the registry hive, manually restore the TrustedInstaller binPath to `%SystemRoot%\servicing\TrustedInstaller.exe` |
| Safeboot flag left set | MEDIUM | Boot into WinRE, run `bcdedit /deletevalue {current} safeboot` from the command prompt |
| DDU removed GPU driver but display not working | MEDIUM | Boot into Safe Mode, run `pnputil /add-driver C:\DisplayDriver.inf /install` or use Windows Update to reinstall the driver |
| Edge removed but WebView2 broken | LOW | Reinstall Edge WebView2 runtime from `https://developer.microsoft.com/microsoft-edge/webview2/` |
| All scheduled tasks deleted | HIGH | Boot into WinRE, restore the TaskCache registry hive from a backup, or rebuild tasks manually |
| BitLocker disable failed | HIGH | Use the BitLocker recovery key to unlock the drive, then retry `Disable-BitLocker` |
| State file wiped | LOW | Manually determine which stage completed by checking registry values and file system state, then re-launch the GUI with a "resume" flag |
| Payload download corrupted | LOW | Re-download the payload, verify the hash, and re-run the stage |
| 7-Zip not installed | LOW | Manually install 7-Zip from `https://www.7-zip.org/`, then re-run the stage |
| Power-cycle mid-stage | HIGH | Boot into WinRE, run the recovery script `C:\ProgramData\AkariOS\recover.ps1`, which restores TrustedInstaller, clears safeboot, and re-enables Defender |
| GUI doesn't resume after reboot | MEDIUM | Manually launch the GUI from `C:\Program Files\AkariOS\AkariOS.exe`, which detects the current state and offers to resume |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| RunOnce entries don't fire | Phase 2 (Core Engine) | Verify RunOnce entry is written to HKLM and read back correctly |
| State file wiped by disk cleanup | Phase 2 (Core Engine) | Verify state file is in `C:\ProgramData\` and survives `cleanmgr` |
| UAC prompting mid-flow | Phase 2 (Core Engine) | Verify GUI is elevated before launching stage scripts |
| Power-cycle mid-stage | Phase 2 (Core Engine) + Phase 4 (Testing) | Verify recovery script exists and can restore critical settings |
| Safe Mode breaks networking | Phase 1 (Foundation) + Phase 4 (Testing) | Verify all payloads are pre-staged in stage 1; test Safe Mode networking in VM |
| TrustedInstaller binPath not restored | Phase 2 (Core Engine) + Phase 4 (Testing) | Verify `sc qc TrustedInstaller` shows default binPath after each `Run-Trusted` call |
| DDU behaves differently in Safe Mode | Phase 2 (Core Engine) + Phase 4 (Testing) | Verify GPU driver state after DDU in Safe Mode VM |
| Deleting all scheduled tasks | Phase 3 (Integration) + Phase 4 (Testing) | Verify critical Microsoft tasks survive after deletion |
| Edge removal breaks WebView2 | Phase 3 (Integration) + Phase 4 (Testing) | Verify WebView2-dependent apps still work after Edge removal |
| Safeboot flag left set | Phase 2 (Core Engine) + Phase 4 (Testing) | Verify `bcdedit /enum {current}` does not show `safeboot` after stepone |
| Disabling security features | Phase 3 (Integration) + Phase 5 (Distribution) | Verify user is warned and can re-enable features |
| BitLocker disable fails | Phase 3 (Integration) + Phase 4 (Testing) | Verify `Get-BitLockerVolume` shows `FullyDecrypted` after disable |
| Windows Update pause too long | Phase 3 (Integration) | Verify pause duration is configurable and defaults to 30 days |
| DISM package removal fails | Phase 3 (Integration) + Phase 4 (Testing) | Verify servicing stack health after DISM operations |
| IWR download failures | Phase 1 (Foundation) + Phase 4 (Testing) | Verify hash of downloaded payload matches expected value |
| 7-Zip dependency | Phase 1 (Foundation) + Phase 4 (Testing) | Verify `Test-Path "C:\Program Files\7-Zip\7z.exe"` after installation |
| Antivirus flagging | Phase 5 (Distribution) | Verify SmartScreen and Defender do not block the GUI |
| `irm \| iex` integrity | Phase 5 (Distribution) | Verify GUI is distributed as compiled executable with hash verification |
| Testing destructive flow | Phase 4 (Testing) | Verify VM-based testing with snapshots and dry-run mode |
| State file wiped (duplicate) | Phase 2 (Core Engine) | Verify state file location and write-before-reboot pattern |

## Sources

- Microsoft Docs: "Run and RunOnce Registry Keys" — https://learn.microsoft.com/windows/win32/setupapi/run-and-runonce-registry-keys
- Microsoft Docs: "BCDedit Command-Line Options" — https://learn.microsoft.com/windows-hardware/drivers/devtest/bcdedit-command-line-options
- Microsoft Docs: "TrustedInstaller and Windows Resource Protection" — https://learn.microsoft.com/windows/win32/srp/windows-resource-protection-portal
- Microsoft Docs: "DISM Command-Line Options" — https://learn.microsoft.com/windows-hardware/manufacture/desktop/dism-command-line-options-servicing-windows-image
- Microsoft Docs: "Windows Update Pause" — https://learn.microsoft.com/windows/deployment/update/waas-configure-wufb
- Microsoft Docs: "BitLocker Disable-BitLocker" — https://learn.microsoft.com/powershell/module/bitlocker/disable-bitlocker
- Microsoft Docs: "Safe Mode Boot" — https://learn.microsoft.com/windows-hardware/drivers/devtest/bcdedit--set
- FR33THY WinSux GitHub repository — https://github.com/FR33THYFR33THY/WinSux
- DDU (Display Driver Uninstaller) documentation — https://www.wagnardsoft.com/display-driver-uninstaller-ddu
- Community: "Windows 11 debloat guide" discussions on Reddit r/Windows11 and r/PowerShell
- Personal experience: multi-reboot installer patterns and failure modes

---
*Pitfalls research for: Destructive Windows setup / debloat automation (AkariOS)*
*Researched: 2026-10-04*
