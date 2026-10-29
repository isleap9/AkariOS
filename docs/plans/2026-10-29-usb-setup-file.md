# Install USB: Schneegans' unattend generator in AkariOS

Decided 2026-10-29. The user asked for "something like" https://schneegans.de/windows/unattend-generator/; a first,
narrower design (setup options plus an AkariOS Preset at the first sign-in) was dropped: the tool is a **full clone**
of Christoph Schneegans' generator (https://github.com/cschneegans/unattend-generator, MIT, ported to PowerShell with
his license and data files in `Core/Unattend/Data/`). It replaces the Legacy "Autounattend" row (AkariOS-Ultimate
`2 Refresh\4 Autounattend.ps1`), which stays until Legacy is retired. Not a Tweak: `Ported.psd1` doesn't list it, and
its Windows settings are his, not Akari's Tweaks (one owner per value applies to Tweaks only).

## Shape

- A Home tile **Install USB**, fourth before Import / Export: one long full-window page of his sections in his order,
  with his wording and choices; Back leads Home. "Open file…" reads a file made on his site or by Akari (the first
  comment is his bookmark URL with every choice; Akari leaves the passwords out of it); "Reset to defaults".
- The choices are his form's fields, with the same names and values, so files, URLs and tests line up with his site.
  Like his page, a branch's fields count only while it is picked.
- Save: a drive list (Windows setup USBs first) and Refresh, "Save to USB" (the root of the drive) and "Save to a
  folder…". A file that wipes a disk (a generated PE stage that partitions), a drive without Windows setup, or an
  existing file ask first. His own checks (names, keys, one administrator, diskpart letters…) show under Save.
- Fidelity: `Tests/Fixtures/Unattend/*.xml` are files made on his site (commit 82d4ffd); the tests require Akari to
  write the same XML for the same choices, and the form to write them again after opening them.

## Batches (each: tests, diffstat, the user's go, commit)

1. **Engine and setup sections** (done 2026-10-29): template, command builder, PowerShell sequences, embedded files;
   region and language, processor architectures, setup settings, the Windows PE stage (edition and keys, generated
   .cmd with disk selection, partition layouts, Windows RE, image, paging file, Defender / 8.3 / compact / pauses, or a
   custom script), activation, computer name, time zone, accounts and first logon, password expiration, lockout,
   Wi-Fi, express settings. Nine fixtures.
2. **His Windows tweak sections** (done 2026-10-29): File Explorer, Start menu and taskbar, Start tiles and pins,
   system tweaks, visual effects, desktop icons, Start folders, core isolation, VM guest tools, lock keys, sticky keys,
   personalization (`Optimizations.cs`, `Personalization.cs` in `Core/Unattend/Windows.ps1`). Five more fixtures.
3. **The rest**: bloatware (his list), custom scripts (System, DefaultUser, FirstLogon, UserOnce; Restart Explorer),
   AppLocker, XML markup for more components.
4. **The VM**: USBs made with Akari for a few option sets, including a disk wipe and Wi-Fi.
