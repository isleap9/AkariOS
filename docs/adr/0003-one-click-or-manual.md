# Install AkariOS (One-click or Guided) and Optimize (Manual) from a Win11Debloat-style Home

Revised 2026-10-19. Akari opens on a full-window Home with no sidebar and three tiles, after Raphire's Win11Debloat start screen. **Install AkariOS** is for a fresh install and offers **One-click** (the old Akari-OS run: prep → Safe Mode → tweaks, reboots handled, after a short Review) or **Guided** (Apps → Tweaks → Review & Apply: nothing changes while choosing, then one Run with a restore point first). **Optimize** is **Manual mode** for power users: every Tweak with its own buttons that act right away, like the legacy Ultimate rows. **Import / Export settings** saves or loads choices. Every page after Home keeps the AkariOS-Ultimate shell (sidebar, header, search, status bar, Ink theme).

Two audiences come from the two old repos: Akari-OS users want one press or a short guided pass; Ultimate users want direct control over each Tweak. Guided gives one restore point, one Outcome list and one reboot prompt per session; Manual keeps the immediate per-Tweak control. Both use the same Core Runner.

Still open: the look of the Guided Tweaks step (WinUI setting cards today, or Win11Debloat's category-card grid), and a new look for Manual mode that moves away from the FR33THY page structure (it shows the old pages until then).

## Considered Options

- **Guided only, legacy pages removed** (the first version of this ADR): rejected; power users lose immediate per-Tweak control.
- **Keep the Ultimate pages as the only UI**: rejected; no guided path for a fresh install, no single Review.
- **A sidebar on Home too**: rejected; the start screen should present the three ways in and nothing else.
