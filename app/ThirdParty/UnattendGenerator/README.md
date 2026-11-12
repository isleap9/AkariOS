# UnattendGenerator (vendored)

Christoph Schneegans' autounattend.xml generator, the library behind
https://schneegans.de/windows/unattend-generator/ (MIT, `LICENSE.txt`).

- Source: https://github.com/cschneegans/unattend-generator
- Pinned commit: `82d4ffdd11ea3266f8f3b29d4fcd80f66bfdbaf6` (2026-10-25), the commit of the files in
  `tests/Fixtures/Unattend/`.
- Copied as they are: `Extensions.cs`, `GlobalSuppressions.cs`, `Main.cs`, `Util.cs`, `Validation.cs`,
  `modifier/*.cs`, `LICENSE.txt`. Left out: `Example.cs` / `Example.ps1` (his console sample), `resource/`.
- Changes to his code: none.
- Changes to his `.csproj`: one target framework (the native app's); his resources are embedded from
  `src/Core/Unattend/Data/` (byte for byte his `resource/` files, which the PowerShell port reads too) under his
  resource names; `IncludeSourceRevisionInInformationalVersion` off, so his Build modifier writes no commit hash
  (the PowerShell port writes none either).
- `app/ThirdParty/Directory.Build.props` keeps AkariOS' build rules (warnings as errors, its version) off this code.

To move to a newer commit: copy the same files from his repo, update `src/Core/Unattend/Data/` with his `resource/`
files, regenerate the fixtures on his site, and port the change to `src/Core/Unattend/` (the PowerShell app) too.

AkariOS reaches it only through `AkariOS.Core/Unattend/` (his form's fields mapped to his `Configuration`).
