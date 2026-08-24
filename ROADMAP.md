# AkariOS Roadmap

Living document — update this file as items land. Checked = shipped.

## ✅ Done

- [x] WinUI 3 shell (AME Beta–style layout: navbar pane as ISO drop zone, single main page)
- [x] Drag-and-drop ISO intake with per-ISO progress items
- [x] ISO mount + staging pipeline (`AkariOS.Core`)
- [x] `$OEM$` payload injection (`sources\$OEM$\$$\Setup\Scripts\` + `SetupComplete.cmd` hook)
- [x] Bootable ISO rebuild with bundled `oscdimg.exe`
- [x] WinSux.ps1 vendored and injected automatically post-install
- [x] Admin self-relaunch (runtime `runas`, manifest-independent)
- [x] App icon (title bar + executable)
- [x] VM-tested end-to-end install

## 🚧 In Progress

- [ ] *(nothing currently)*

## 📋 Backlog

### Servicing
- [x] Direct WIM image servicing via ManagedWimLib — payload baked into `install.wim` (`\Windows\Setup\Scripts` + RunOnce hook) in addition to `$OEM$`; auto-skips ESD media (6a243b7)
- [x] Edition/index selection UI — editions scanned at intake (mount → wimlib → dismount), checkbox picker per ISO, unticked editions left untouched (2d4a842)

### UX
- [ ] Per-ISO tweak selection UI (choose which parts of the playbook to apply)
- [ ] Custom payload support — bring your own scripts alongside WinSux
- [ ] Build cancellation
- [x] Build log viewer in-app (collapsible mono pane per ISO item; streams oscdimg/robocopy output)

### Distribution
- [x] Release builds + GitHub Releases CI (`.github/workflows/release.yml`, tag `v*`)
- [ ] USB flasher — write finished ISO straight to a bootable drive
