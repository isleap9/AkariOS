# Optimize › Advanced is the full catalogue, acting right away; Legacy goes once ported

Decided 2026-10-22. Optimize › Advanced shows every one-file Tweak, in a sidebar of Section › Category pages with
search, and each change acts right away, like Legacy's buttons: Toggles as switches, Choices as dropdowns, Actions as
buttons, one change at a time in the background. It is where new Tweaks land: the rest of Legacy and the ZOICWARE
tweaks are ported into it in batches (plan `docs/plans/2026-10-22-optimize-advanced.md`). Guided stays the short,
pick-then-apply path over the same Tweaks; a Tweak can opt out of Guided (`Guided = $false`), and Section Tools never
shows there. Safe Mode Tweaks wait in a bar and run together in one Run in phases; restarts are collected in a bar
and only happen when the user asks.

Once every Legacy row has a one-file owner or was deliberately dropped (after the Legacy tools batch), Legacy is
removed: the generated files, the `Add-Tweak` adapter, the shims, `Ported.psd1` and the chooser card. That later
change gets its own ADR, which replaces ADR 0004 (Legacy frozen, not deleted).

Acting right away keeps the manual mode that Legacy's users know, and it is what a power user expects from a settings
catalogue (Winhance, Windows Settings). Guided already covers choose-review-apply, so Advanced does not repeat it.

## Considered Options

- **Advanced as the extras only** (Tweaks not in Guided): rejected; a power user would need both pages to see one
  area, and every port would have to decide where it lives.
- **Advanced with Guided's Selection and Review & Apply**: rejected; that is Guided again, and it loses the immediate
  feedback of Legacy.
- **Keep Legacy forever next to Advanced**: rejected; two implementations of the same setting drift apart (the cost
  ADR 0004 accepted only while the port is unfinished).
- **Port Tweaks that install outside tools** (ExplorerPatcher, OpenShell, TranslucentTB…): rejected for now; their
  Revert depends on uninstallers Akari does not control.
