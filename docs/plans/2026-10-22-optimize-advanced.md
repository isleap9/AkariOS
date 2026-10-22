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
4. **Retire Legacy** (a new ADR replacing 0004): delete the 7 generated files, `Core/Legacy.ps1`, `Core/Compat.ps1`,
   `Tweaks/Ported.psd1` and the Legacy card; Optimize opens Advanced directly.
5. **Batch 3, ZOICWARE registry and group policy tweaks** (`registrytweaks.md`, `src/RegTweaks.txt`).
6. **Batch 4, ZOICWARE services, scheduled tasks and power** (its "set services to manual" meets
   `advanced-services-off`: one owner, so a Choice or a note).
7. **Batch 5, ZOICWARE optional tweaks and the Ultimate Context Menu**.
8. **Batch 6, ZOICWARE Windows 11 tweaks** that need no outside tool.
9. **Batch 7, the rest of ZOICWARE**: its debloat (rows on Apps › Remove), installers (Downloads), the stripped Nvidia
   driver install (Tools › Drivers), Ultimate Cleanup (Tools › Cleanup). Config import / export is M5's.
