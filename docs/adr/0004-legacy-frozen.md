# Legacy tweaks are frozen, not deleted as they are ported

Decided 2026-10-19. The AkariOS-Ultimate tweaks (the 7 generated `Tweaks/*.ps1` files, loaded through the `Add-Tweak` adapter in `Core/Legacy.ps1` with the shims in `Core/Compat.ps1`) are **Legacy**. They stay as they are and keep working on Optimize › Legacy, the old pages where each button acts right away. Porting a script to one-file tweaks never edits or deletes its legacy entry. Instead `Tweaks/Ported.psd1` maps the legacy id to the one-file ids that fully replace it, and Guided hides the legacy row once it is listed there. A legacy id is listed only when every value it sets has a one-file owner.

This replaces the old migration rule ("delete the `Add-Tweak` entry once ported, delete the adapter with the last category"). The port changes much more than the code: per-OS Defaults, `Detect`, `Requires`, split or merged tweaks. Some of those changes will be wrong at first, and the Legacy pages are the tested fallback while that happens. Power users also keep the pages they know.

The cost is that the same setting has two implementations that can drift apart. The one-file tweak is the one that gets fixed; Legacy only gets a fix when it is broken.

## Considered Options

- **Delete each legacy entry once ported** (the original plan, AkariOS-PLAN.md §11 step 3): rejected; it leaves no fallback while the new tweaks are untested, and the Manual pages would lose rows one batch at a time.
- **Regenerate Legacy from the ported tweaks**: rejected; legacy rows are hand-written bodies, not data, so nothing could be generated back.
