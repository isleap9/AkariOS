# ISO Builder: zoicware's zISO Tweaker in AkariOS

Decided 2026-10-31. The user added `_ref/zISOTweaker-main` (zoicware, MIT) and asked for its feature in Akari: a
custom Windows 11 ISO built from a stock one (apps and features removed, settings written into the image offline).
Akari-flavoured, not a 1:1 clone. Not a Tweak: nothing here touches the running PC, `Ported.psd1` doesn't list it,
and one owner per value applies to Tweaks only.

## What zISO does (the reference)

`functions/zISOTweaker.ps1` + `ISOTweakerFuncs.psm1`: ADK for oscdimg; ISO copied out; an edition of
`install.wim` (`.swm` exported to one wim first) mounted; provisioned apps, OS packages, capabilities and optional
features removed (lists read from the image); the image's SOFTWARE, SYSTEM, default user NTUSER, DEFAULT and
COMPONENTS hives loaded as `HKLM\OFFLINE_*` and written; NetFx 3.5 enabled from `sources\sxs`; component cleanup,
commit, export with max compression; `boot.wim` index 2 gets the requirement bypass; `oscdimg` (BIOS + UEFI) builds
`<name>(Z).iso`.

## Decisions

- **Its own tab and Home tile, "ISO Builder"** (after Unattend Generator), a full-window page like the Unattend
  Generator's, Back leads Home.
- **Windows 11 only** (zISO's steps are W11 ones). An ISO whose image is older than build 22000 is refused.
- **Sources**: Browse to an `.iso`; **UUP Dump** inside Akari (version 23H2 / 24H2 / 25H2 / 26H2 = builds 22631 /
  26100 / 26200 / 26300, newest retail build of it, any language UUP Dump lists, edition Home / Pro / their N, or a
  virtual edition: Enterprise, Education, IoT Enterprise, Pro Education, Pro for Workstations; built from Microsoft's
  files by UUP Dump's converter); **Massgrave** for what UUP Dump can't make (LTSC, IoT LTSC, other consumer /
  business media): Akari lists Massgrave's catalogue (product, language, file name: parsed from the markdown of
  `massgravel/massgrave.dev` on GitHub), opens the chosen link in the browser, then finds the downloaded file in the
  user's Downloads by its name. Massgrave's hosts (zerofs.link, buzzheavier.com) are web pages that block scripts, so
  Akari never downloads from them itself (zISO's Massgrave button looks for a microsoft.com link that is gone).
- **Offline settings = zISO's set as data** (rows for the `OFFLINE_*` hives, file lists), not Akari's Tweaks.
  Always on: Windows 11 requirements off (install.wim and boot.wim), sponsored apps and content delivery off, Teams /
  new Outlook auto-install off, WPBT and co-installers off, first logon animation off, compatibility appraiser / CEIP
  tasks removed, Cross Device Resume removed, UCPD off, AI Fabric and Windows Quality / Health Insights services off,
  classic context menu (RunOnce), Internet Explorer and Windows Mail folders removed, `DeviceRegion` = 68,
  NetFx 3.5. Options (zISO's): Disable all updates, Security updates only (the two exclude each other), Disable
  version upgrades, Remove Defender (features, SecHealthUI, files, zISO's 11 .reg files as rows), Remove BitLocker,
  Disable mitigations, Disable telemetry, Remove Windows AI, Remove Edge, Remove OneDrive.
- **Remove Windows AI without zoicware's .cab**: zISO installs a .cab from zoicware's GitHub and adds zoicware's root
  certificate (`8A334AA8…`) to the image for it. Akari keeps the policies, Recall feature, AI packages, files,
  services and tasks, and adds no certificate.
- **AkariOS on the desktop**: this Akari version copied into the image's `C:\AkariOS` with a Start menu shortcut for
  all users (as `build/Bootstrap.ps1` installs it); nothing runs by itself. No zoicwareOS download.
- **Answer file** (default chosen here, the user can change it): `autounattend.xml` at the ISO root, from Akari's
  Unattend Generator engine: "Local account" (user name, password, skip OOBE: zISO's fields, with this PC's
  language, keyboard and time zone instead of zISO's hard-coded en-US / Central), "Unattend Generator's choices"
  (the page's current state or a file), or none. zISO's `FirstRun.ps1` (taskbar pins, start2.bin) is dropped: Akari's
  own Tweaks do that after install.
- **Work folder**: an output folder the user picks (NTFS, ~25 GB free checked first); `AkariIso\Media` (the ISO's
  files) and `AkariIso\Mount` in it. A build left mounted (crash, power loss) is discarded on the next launch (zISO's
  `Reset-ISOMount.cmd` instead).
- Runs in the background job with real progress (`Set-AkariProgress`, a step per stage); the window stays usable but
  a second build or a Catalogue change waits.

## Shape (Core)

- `Core/Iso.ps1`: the build. `Get-AkariIsoEditions <wim>`, `New-AkariIsoPlan <choices>` (pure: the ordered steps),
  `Invoke-AkariIsoBuild <choices>`, `Clear-AkariIsoLeftover`. Native and system-changing calls only through
  wrappers the tests mock: `Mount-AkariDiskImage` / `Dismount-…`, `Mount-AkariWim` / `Save-AkariWim` /
  `Undo-AkariWim`, `Export-AkariWim`, `Invoke-AkariDism <args>`, `Mount-AkariOfflineHives` / `Dismount-…` (through
  `Invoke-AkariRegExe`), `Install-AkariAdk`, `Invoke-AkariOscdimg`. Image reads: `Get-AkariImageApps`,
  `-Features`, `-Capabilities`, `-Packages`.
- `Core/Iso/Data/`: `Always.psd1`, one `.psd1` per option (registry rows for the offline hives, file and folder
  lists, feature / package name patterns), zISO's license.
- `Core/IsoDownload.ps1`: UUP Dump through `Invoke-AkariUupApi` (never throws; retries like zISO) →
  `Get-AkariUupBuild <version>`, `Get-AkariUupLanguages`, `Get-AkariUupEditions`, `Save-AkariUupIso` (the converter
  package, `ConvertConfig.ini` patched as zISO does, run through `Invoke-AkariExe`); Massgrave: `Read-AkariMassgrave
  <markdown>` (pure, a fixture in `tests/Fixtures/`), `Get-AkariMassgraveCatalogue`, `Find-AkariDownloadedIso <name>`.
- `UI/IsoBuilder.ps1` (+ pure helpers first, tests dot-source them): the page in zISO's order: 1 Source,
  2 Edition, 3 Answer file, 4 Windows Update, 5 Security and privacy, 6 Apps (four tables read from the mounted image
  in the background, Akari's table look; Select recommended = FR33THY's keep-list as the Remove tab), 7 AkariOS,
  Build (output folder, free space, Build ISO, progress, result with Open folder).

## Batches (each: tests, diffstat, the user's go, commit)

1. **Engine** (done 2026-10-31): copy-out, editions, mount / commit / discard, offline hives, always-on settings, NetFx 3.5, boot.wim,
   compression, oscdimg + ADK, leftover cleanup. Tests mock every wrapper and check the plan and the call order.
2. **Options and removals** (done 2026-10-31): the ten options as data, app / feature / capability / package removal, AkariOS copy,
   answer file at the root.
3. **Downloads** (done 2026-10-31): UUP Dump (API mocked, converter mocked) and the Massgrave catalogue (parser on a fixture).
4. **The page**: tab, Home tile, `$Pages` entry, the sections, background reads, the build job and its result.
5. **The VM**: a 25H2 Pro build from UUP Dump, an IoT LTSC 2024 ISO from Massgrave, each with a few option sets,
   installed in a VM.

Credits: zoicware's zISO Tweaker (MIT) in `CREDITS.md`; UUP Dump and abbodi1406's converter named on the page.
