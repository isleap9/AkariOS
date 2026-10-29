# Install USB: AkariOS's own Windows install USB builder

Decided 2026-10-29 in two design sessions, after Christoph Schneegans' unattend generator
(https://schneegans.de/windows/unattend-generator/, MIT: ideas and XML know-how, credited). It replaces the Legacy
"Autounattend" row (AkariOS-Ultimate `2 Refresh\4 Autounattend.ps1`: a fixed en-US / Central Standard Time file, the
account name and drive letter typed in the console). The Legacy row stays until Legacy is retired, then goes with it.
Not a Tweak: `Ported.psd1` doesn't list it.

## Scope

The form covers what only an answer file can do, in depth. Everything Windows itself can change later (Explorer,
taskbar, Start, UAC, Edge, visual effects, bloatware) comes from AkariOS's own Tweaks: the user picks a Preset that
runs at the first sign-in. One owner per setting, no duplicated checkboxes. Not taken from Schneegans: custom
scripts, AppLocker, VM guest tools, extra XML components, disk criteria and custom diskpart scripts.

## The flow

A Home tile **"Install USB"** ("Prepare a Windows install USB: your accounts, language, edition and AkariOS preset,
no setup questions"), fourth before Import / Export. A full-window step flow with dots, Back / Next, like Guided:

1. **Region**: display language (the 38 Windows ships, "must be a language your ISO has"); up to three input
   languages, each with its keyboard (the first follows the display language); region format; home location (a
   country); time zone, set explicitly. All prefilled from this PC. "Ask for these during setup instead".
   An **Open…** button loads a file Akari made back into the form (the choices are a comment in the XML, never the
   passwords).
2. **Windows setup**: edition: ask during setup (default) / an edition by Microsoft's public generic install key
   (Home, Pro, Pro for Workstations, Education, Enterprise: they pick the edition and never activate) / my own key /
   the firmware's key. Skip Windows 11's hardware checks (on), allow setup without internet (on), hide PowerShell
   windows during setup (on), express settings: all off (default) / all on / ask; compact mode (off).
   **Disk**: "I choose the disk during setup" (default); Advanced: "Wipe disk N and install" (index, GPT or MBR,
   Windows RE on a recovery partition or removed), a red warning, confirmed again on Save.
3. **Accounts**: up to five local accounts (name, display name, password, Administrators / Users; at least one
   administrator); PC name: random or a name; the first administrator signs in once by itself (with a password: a
   one-time auto sign-in, LogonCount 1, so the preset starts unattended); password expiry: never (default) / the
   Windows default; lockout: the Windows default / off. No Microsoft account, no built-in Administrator. Passwords
   are base64-encoded, with the warning that anyone with the USB can recover them.
4. **Network**: Wi-Fi: skip (default) / ask during setup / this network (name, hidden, WPA2 or WPA3, password: plain
   text in the file, warned).
5. **After install**: a Preset (None / built-in / the user's / Last used). At the first sign-in the copy of AkariOS
   on the USB goes to `C:\ProgramData\Akari\app` and stays (a Run in phases comes back through `-Resume`; a Start
   menu shortcut, updated from About as usual), then `Akari.ps1 -Preset <name>` runs in its console, Safe Mode
   phases and restarts included. No restore point (Windows is new).
6. **Save**: a summary of the choices; a drive list (Windows setup USBs first) and Refresh; "Save to USB" writes
   `autounattend.xml` at the root and, with a Preset, `\AkariOS\` (this version: the release folders only) and the
   preset file; a drive without Windows setup, existing files, or a disk wipe ask first; then it opens the drive.
   "Save to a folder…" writes the same (Ventoy, Rufus, ahead of time). Run through iex (no install folder): the
   AkariOS copy is the latest release, downloaded on Save.

## Code

- `Core\Unattend.ps1`: `New-AkariUnattend <options>` → the XML, assembled from one builder per section (region,
  setup and disk, accounts, network, first logon), each tested on its own; `ConvertFrom-AkariUnattend <xml>` → the
  options back (the comment); `Test-AkariUnattendName`; `Get-AkariUnattendDefaults`; `Get-AkariSetupDrives` (the only
  drive read, mocked); `Save-AkariUnattend`; `Copy-AkariToUsb <target> <preset>` (the AkariOS copy and the preset).
- `UI\Unattend.ps1` + `UI\Unattend.psd1` (languages and keyboards, home locations, generic keys): the flow.
- Credits: Schneegans' generator in CREDITS.md and UI\About.psd1.

## Tasks (one at a time: diffstat, then the user's go)

1. The builders, test-first: region, setup (edition, bypasses, express settings, compact, disk), accounts (several,
   auto sign-in, expiry, lockout), network, first logon (the preset run), the options comment and Open.
2. The AkariOS copy and the preset on the USB (`Copy-AkariToUsb`, the first-logon script).
3. The flow (six steps), the Home tile, credits, AGENTS.md.
4. On the VM: a USB per option set (no password, password + Wi-Fi, a disk wipe, the AkariOS preset).
