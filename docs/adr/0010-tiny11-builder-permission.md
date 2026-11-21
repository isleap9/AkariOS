# The ISO Builder takes Tiny11 Builder's removal sets, with its developers' permission

Decided 2026-11-21. Supersedes the plan `docs/plans/2026-11-20-iso-builder-wizard.md`'s "ideas only" rule for
Tiny11 Builder.

[Tiny11 Builder](https://github.com/ntdevlabs/tiny11builder) (ntdevlabs) has no licence file, so it was first
treated like Winhance: its flow and layout only. Its images come out about 2 GB smaller than AkariOS's, mostly from
what it removes and how it compresses. The project owner asked its developers and reports that they allowed AkariOS
to use it (2026-11-21); the record is `docs/permissions/tiny11builder.md`.

So AkariOS ports what `tiny11maker.ps1` (Tiny11) and `tiny11Coremaker.ps1` (Tiny11 Core) do, at commit
`38f7ab6b1f177098c026a19b73ec84bca9c4b874`, into its own ISO Builder data: removal groups in
`src/Core/Iso/Wizard/Groups/` whose headers name the script and lines they come from, run by AkariOS's own engine
(DISM API, offline hives, TrustedInstaller), not their scripts. Tiny11's set is the Lite mode; Core's becomes
Minimal (I6).

## Consequences

- CREDITS.md credits Tiny11 Builder for the ISO Builder's removal groups.
- The modes keep AkariOS's names (AkariOS, Lite, Minimal, Custom).
- If the permission is ever withdrawn, the groups marked from Tiny11 Builder are rewritten from Microsoft's
  documentation, as the first plan did.
