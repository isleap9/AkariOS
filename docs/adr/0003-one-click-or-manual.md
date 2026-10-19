# Home offers AkariOS one-click or Manual; the GUI inside the shell is rebuilt

On opening, the user chooses **AkariOS one-click** (the old Akari-OS run: prep → Safe Mode → tweaks, reboots handled, after a short Review) or **Manual** (guided steps Apps → Tweaks → Review & Apply, Win11Debloat-style: nothing changes while choosing, then one Run with a restore point first). Install and Utilities are Zoicware-style toolbox pages that run one-shot Actions at any time. To fit this flow, we keep the AkariOS-Ultimate shell and Ink theme (window chrome, Mica, sidebar, header, search, status bar) but replace everything inside it: per-row Optimize / Default buttons, state dot, risk badges, log drawer, tuners, the old 8 pages and the old Home. Controls inside pages look like native WinUI 3 (setting cards, ToggleSwitch, ComboBox, expanders), dark only.

Per-row buttons that act immediately made every click a Run, gave no overview of what would change, and mixed one-shot Actions with revertible Toggles on the same pages. Choosing first and applying once gives one restore point, one Outcome list and one reboot prompt per session, and lets the one-click path and the Manual path share the same Runner.

## Considered Options

- **Keep the Ultimate pages and row buttons, restyle only**: rejected; keeps the click-to-run model and the 8 legacy pages that don't match the new Sections.
- **Rebuild the whole GUI, shell included**: rejected; the shell (Mica, chrome, sidebar, search, theme) already works and isn't the problem.
- **One-click only (old Akari-OS)** or **Manual only (old Ultimate)**: rejected; the product merges both repos, so both audiences need a path.
