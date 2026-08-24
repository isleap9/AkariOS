# AkariOS — TODO

_Next-session plan. Sync with [ROADMAP.md](ROADMAP.md) as items land._

## 1. Release CI + GitHub Releases ⭐ first task
- Workflow that builds `AkariOS.exe` (win-x64, self-contained WinAppSDK) on tag push
- Attach artifact to a GitHub Release

## 2. UX polish
- [x] Build cancellation support — robocopy/oscdimg are killed on cancel, partial output deleted (0bc3e2a)
- [x] In-app build log viewer (a5af2a3)

## 3. Direct WIM servicing via ManagedWimLib 🏗 big one
- Library is vendored in `third_party/` but unused
- Inject tweaks directly into `install.wim` instead of relying on `$OEM$`/SetupComplete only
- **Discuss approach before starting** (architectural decision)
- Unlocks: edition/index selection for multi-image WIMs

## Done recently
- VM-tested end-to-end install (WinSux runs post-install via SetupComplete.cmd)
- Title bar icon (40×40, original logo colors)
- README.md + ROADMAP.md committed
