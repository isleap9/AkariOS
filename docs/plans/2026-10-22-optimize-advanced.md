# Optimize › Advanced: the full catalogue

Decided 2026-10-22 in a design session (ADR 0005). Optimize › Advanced becomes the complete catalogue of one-file Tweaks,
acting right away like Legacy; then the rest of Legacy and ZOICWARE (`_ref/ZOICWARE`, MIT) are ported into it in
batches, and Legacy is retired.

## The page

- **Content**: every one-file Tweak (all Sections), today 158, plus every port to come. Guided's Tweaks step keeps
  showing them too, except a Tweak whose file says `Guided = $false` (Advanced only: niche or risky ports) and Section
  **Tools** (never in Guided, like Apps and OneClick). Each port batch proposes which Tweaks get `Guided = $false`.
- **Navigation**: the sidebar, like Legacy's: `← Optimize`, then Section › Category pages (Optimize, Customize,
  Graphics & Hardware, Advanced, Tools). Search covers every Tweak (name and description); the matches show on a
  "Search results" page grouped by Section › Category, with working controls.
- **Cards** (Winhance / Windows Settings style, a list per page): name, description, Risk badge, a State label
  (Optimized / Windows default / Custom / Unknown, "(AkariOS)" when the Tweak is part of the AkariOS setup), restart
  and Safe Mode glyphs, and the control on the right: a switch for a Toggle (On = Optimized; neither on nor off for
  Custom or Unknown), a dropdown for a Choice ("(Recommended)" and "(Windows default)" marked), a button for an
  Action. Selecting an Advanced Tweak or a riskier Choice value asks first (Get-AkariConfirmText, the dark dialog).
- **States**: a page opens at once and reads its States in the background; each control stays greyed until its State
  arrives. A refresh button in the page header reads them again.
- **Changes act right away**, one at a time in the background job. Quick clicks queue and run in order; the card shows
  a spinner while its change waits or runs, then its new State, or a red one-line error (also logged). The first
  change of the session gets an AkariOS restore point first (Get-AkariRestoreChoice 'Optimize', as on Legacy).
- **Safe Mode Tweaks** don't run at once: they wait in a bar at the bottom ("2 changes need Safe Mode
  [Restart and apply]"), which starts one Run in phases (Core\Phases.ps1) for all of them. Switching one back before
  that takes it out of the bar. The bar keeps them across pages; closing Akari with changes waiting asks
  "Restart and apply / Discard".
- **Restarts**: changes that need Explorer restarted or a PC restart add to a notice bar ("Explorer needs a restart
  to show 3 changes [Restart Explorer]", "A restart finishes 2 changes [Restart now]"); nothing restarts by itself.
- **No bulk buttons** in v1 (no "apply all on this page" / "revert this page"): Presets and Guided cover bulk changes.
- **Chooser**: Advanced becomes active (a note says more Tweaks are coming while the batches run). Legacy stays,
  titled as being retired, until batch 2 is done.
- **Guided** gets a small heading per Section above its cards (no more two "System" cards).

## Porting rules

- One owner per registry value (`Find-AkariRegistryOwner`). When a second source sets the same value differently: a
  real alternative becomes another value of the existing Tweak (a Choice); otherwise it is skipped with a note in the
  file.
- Not ported: Tweaks that need an outside tool (ExplorerPatcher, OpenShell, TranslucentTB, toggle-rounded-corners,
  PBO Tuner, Dark Winver), and Windows activation workarounds (ZOICWARE's public KMS activation, the legacy "Keys"
  link to Microsoft Activation Scripts). Opening Windows' own activation settings stays.
- Every Toggle and Choice reverts to the Windows Default (ADR 0001); Actions say why they have none.
- Credits in CREDITS.md and UI\About.psd1 (ZOICWARE gets a line when its first batch lands).

## Tasks (one at a time: diffstat, then the user's go)

0. This plan, ADR 0005, AkariOS-PLAN.md §4, GLOSSARY.md.
1. **The page** on today's 158 Tweaks: sidebar and pages, cards, background States, the change queue, the Safe Mode
   bar, the restart bar, search, the `Guided` field and Section Tools (Loader, Get-AkariStepGroups), the chooser card,
   Guided's Section headings. Tests: pure helpers (page list, search, the queue and bars' state) and the UI probe.
2. **Batch 1, Legacy settings leftovers**: Copilot (app removal), Game Bar (its Revert), Game Mode, pointer precision,
   scaling, sound, the Control Panel blobs (focus / priority notifications, app actions, Explorer `IsEnabled`),
   core isolation (an Open Action).
3. **Batch 2, Legacy tools** into Tools: Check (BIOS, GPU, RAM, storage, FurMark, OCCT), Refresh (local account,
   autounattend, factory reset, network driver, reinstall, boot to BIOS, block driver updates), Drivers (clean,
   debloat, install, install settings), runtimes (C++, DirectX), the Hardware tools (bufferbloat, controller and mouse
   tests, monitor, PC build, scaling), Setup's Open shortcuts; and the legacy Windows Actions (autoruns check,
   bloatware, restore point).
   Decided 2026-10-27, in three commits: **2a** the simple tools (Check, Refresh, Setup's activation and Home to Pro,
   a new `Home` Requirement; Settings shortcuts as Open buttons in their Category; Check programs from winget when
   missing; Reinstall = Microsoft's own Media Creation Tool; BIOS check no longer restarts), **2b** DDU, the driver
   installs, controller overclock, autounattend, the updates and drivers block, **2c** the Bloatware leftovers
   (OneDrive, Remote Desktop Connection, Snipping Tool to Downloads; the checks to Tools › Check), autoruns check,
   restore point, ReBar (a Choice in Hardware › Graphics) and scaling (a Choice in Hardware › Input). C++ and DirectX
   were already Downloads apps, the HAGS / windowed page already two Toggles. Dropped (listed in the Legacy ADR): PC
   build guide (a third party's list), Keys (an activation workaround), "Install all UWP apps", and the per-game
   process priority, SMT / HT and core 1 thread 1 tools (Task Manager's Set priority / affinity; Process Lasso).
   2b as built: DDU clean / manual are SafeMode Actions with a new `Prepare` field (DDU is downloaded in normal mode,
   before the restart: Safe Mode has no network); per vendor "install latest driver" and "... debloated" (AMD and
   Intel take the newest full package from Downloads, no file picker); hidusbf; the updates and drivers block = two
   group-policy Toggles in Optimize › Update (a new `Pro` Requirement), its USB variants dropped. **Autounattend left
   batch 2**: it becomes AkariOS's own tool, a Home card, designed in its own session after 2c; the Legacy retirement
   follows it, then the ZOICWARE batches (Advanced keeps growing).
   2c as built: ReBar = a Toggle (force on; Revert re-imports the matching Base Profile; Force Off dropped), scaling
   with no mouse acceleration dropped (its curves do nothing with Enhance pointer precision off), One-click's
   startup cleanup and restore point moved to Tools (ids kept), Autoruns and three Opens in Tools › Check, OneDrive,
   Remote Desktop Connection and the old Snipping Tool in the restore card. **2d**: a "Remove apps" flow (the Remove
   tab alone, like Downloads) opened from the Catalogue sidebar, with Downloads next to it, so Advanced can debloat.
   2d as built (2026-10-29): Remove apps = the Remove tables (Select recommended, AkariOS, Clear selection, Only
   installed; no Quick select menu, since a preset holds Tweaks the flow never shows), then Review & Remove, with the
   session's restore point. Remove apps and Downloads sit at the top of the Catalogue sidebar; Back on the first step
   and Done return to the Catalogue page they were opened from. No Home tile. Only a Guided Run saves Last used now.
4. **Retire Legacy** (a new ADR replacing 0004): delete the 7 generated files, `Core/Legacy.ps1`, `Core/Compat.ps1`,
   `Tweaks/Ported.psd1` and the Legacy card; Optimize opens Advanced directly.
5. **Batch 3, ZOICWARE registry and group policy tweaks** (`registrytweaks.md`, `src/RegTweaks.txt`).
   Decided 2026-10-29: of its 196 entries 116 were already AkariOS Tweaks (same values); only the new values are ported,
   a partial overlap's missing values becoming a new Tweak (the overlapped Tweaks are all in the AkariOS setup, which
   stays as it is). Every port is `Guided = $false`, never AkariOS, Revert = the stock default (a policy value: deleted),
   one Tweak per entry (the newer app permissions merged, the camera on its own). **3a** (done): privacy, system,
   performance, security, update. Skipped: the user choice driver and the DataCollection CurrentVersion values (stock
   defaults unknown), WPBT and hibernate (already Tweaks), "Remove logons" (Tools > Cleanup), a feedback value delete,
   the drag tray feature flag. `Tests/Zoicware.Tests.ps1` round-trips every port. **3b**: Explorer, taskbar, Start,
   notifications, input and appearance.
6. **Batch 4, ZOICWARE services, scheduled tasks and power** (its "set services to manual" meets
   `advanced-services-off`: one owner, so a Choice or a note).
7. **Batch 5, ZOICWARE optional tweaks and the Ultimate Context Menu**.
8. **Batch 6, ZOICWARE Windows 11 tweaks** that need no outside tool.
9. **Batch 7, the rest of ZOICWARE**: its debloat (rows on Apps › Remove), installers (Downloads), the stripped Nvidia
   driver install (Tools › Drivers), Ultimate Cleanup (Tools › Cleanup). Config import / export is M5's.
