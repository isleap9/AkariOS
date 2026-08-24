# AkariOS

<p align="center">
  <img src="src/AkariOS.App/Assets/AppIcon.png" alt="AkariOS logo" width="96"/>
</p>

**AkariOS** is a Windows ISO builder with debloat and gaming tweaks built in. Point it at a stock Windows 10/11 ISO, and it injects the [WinSux](https://github.com/FR33THYFR33THY/WinSux) playbook so your tweaks run automatically during installation — one ISO, fully set up, ready to boot.

No pre-baked images, no trust-the-internet downloads of someone else's ISO. You build it yourself from media you already own.

---

## How it works

1. **Drop in an ISO** — drag `.iso` files onto the sidebar (or use *Add ISO*). Each ISO shows as an item with live progress.
2. **Build** — AkariOS mounts the ISO, stages a copy, and injects the payload:
   - `WinSux.ps1` lands in `sources\$OEM$\$$\Setup\Scripts\`
   - A `SetupComplete.cmd` hook triggers it automatically after Windows Setup finishes
3. **Rebuild & save** — the staged tree is repacked into a **bootable ISO** using a bundled `oscdimg.exe`. No ADK install required.

The result: install Windows normally, land on the desktop with all tweaks already applied — nothing extra to run by hand.

## Features

- 🖱️ Drag-and-drop ISO workflow with per-ISO progress tracking
- 🔧 Automatic `$OEM$` payload injection (`SetupComplete.cmd` runs WinSux after first logon)
- 💿 Bootable ISO rebuild via bundled `oscdimg.exe` — zero external dependencies for end users
- 🧩 Modular build pipeline (`AkariOS.Core`) — steps are isolated and extensible
- ⚡ Self-contained WinUI 3 app — no runtime installs needed on the target machine

## Screenshots

> *(coming soon)*

## Getting started

### Prerequisites

- Windows 10 21H2+ / Windows 11
- [.NET 10 SDK](https://dotnet.microsoft.com/download)
- The [Windows App SDK](https://learn.microsoft.com/windows/apps/windows-app-sdk/) runtime is self-contained — no separate install needed
- A Windows 10/11 ISO to modify

### Build

```bash
git clone https://github.com/isleap9/AkariOS.git
cd AkariOS
dotnet build src/AkariOS.App -c Release
```

The executable is `src/AkariOS.App/bin/Release/net10.0-windows10.0.26100.0/win-x64/AkariOS.exe`.

> ⚠️ AkariOS requires **administrator privileges** to mount ISOs and write to the staging tree. It will self-relaunch elevated on startup.

## Project structure

```
AkariOS/
├── src/
│   ├── AkariOS.App/         # WinUI 3 shell — title bar, navigation, ISO drop pane
│   ├── AkariOS.Framework/   # MVVM infrastructure (CommunityToolkit.Mvvm base)
│   ├── AkariOS.Core/        # Build pipeline: mount → stage → inject → oscdimg
│   │   └── Inject/          # $OEM$ payload injection (OemInjectStep)
│   └── AkariOS.Tests/       # Unit tests
├── WinSux/                  # Vendored WinSux.ps1 debloat/gaming-tweak script
└── third_party/
    └── ManagedWimLib/       # WIM manipulation library (reserved for future direct WIM injection)
```

## Roadmap

- [ ] Direct WIM image servicing via `ManagedWimLib` (inject without `$OEM$`)
- [ ] Per-ISO tweak selection UI
- [ ] USB flasher — write the finished ISO straight to a bootable drive
- [ ] Custom payload support (bring your own scripts alongside WinSux)

## Acknowledgements

- [WinSux](https://github.com/FR33THYFR33THY/WinSux) by FR33THY — the debloat & gaming-tweak playbook AkariOS ships
- [ManagedWimLib](https://github.com/soleon/ManagedWimLib) — .NET wrapper for libwim

## License

See [LICENSE](LICENSE).
