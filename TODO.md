# AkariOS — TODO

_Next-session plan. Sync with [ROADMAP.md](ROADMAP.md) as items land._

## 1. Release CI + GitHub Releases ⭐ first task
- Workflow that builds `AkariOS.exe` (win-x64, self-contained WinAppSDK) on tag push
- Attach artifact to a GitHub Release

## 2. UX polish
- [x] Build cancellation support — robocopy/oscdimg are killed on cancel, partial output deleted (0bc3e2a)
- [x] In-app build log viewer (a5af2a3)

## 3. Direct WIM servicing via ManagedWimLib 🏗 ✅ DONE (6a243b7)
- SDK-style wrapper `ManagedWimLib.net` over vendored sources; ships libwim-15.dll
- `WimServiceStep` bakes payload into every edition of `install.wim`; ESD skipped
- Gotchas solved: OpenFlags.WriteAccess required for Overwrite; wimlib reads file data at commit time (keep temp sources alive); use WriteFlags.Rebuild
- Next: edition/index selection UI (ListImages already exists)

## Done recently
- VM-tested end-to-end install (WinSux runs post-install via SetupComplete.cmd)
- Title bar icon (40×40, original logo colors)
- README.md + ROADMAP.md committed
