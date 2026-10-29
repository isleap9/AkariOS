# AkariOS Glossary

## Tweaks

**Tweak**: one change to Windows that Akari can make, defined in its own file and addressed by a unique kebab-case id. Every Tweak is a Toggle, a Choice, an Action or a Group.
_Avoid_: row (that is only how a Tweak appears in the GUI), script, setting

**Toggle**: a Tweak that can be both applied and reverted, and whose State can be read.
_Avoid_: switch, option

**Action**: a one-shot Tweak with no revert, such as an installer or a check.
_Avoid_: command, task

**Group**: a Tweak that bundles Entries under one heading, optionally with a main button that runs them all. Groups do not nest.

**Entry**: a Tweak that lives inside a Group, addressed as `<group-id>/<name>` so a Preset can target it on its own. It can be any kind except Group.
_Avoid_: sub-action, item, child

**Apply**: perform a Tweak's change. In Guided, ticking a Toggle (or picking a Choice value) selects Apply and nothing happens until Review & Apply; on Optimize › Advanced, turning its switch On applies it right away (ADR 0005).
_Avoid_: optimize (as a verb in code or docs), enable, run

**Revert**: put a Toggle back to its Default. In the GUI, turning the switch Off (or picking the Windows default value) selects Revert.
_Avoid_: undo, restore, reset

**Default**: the stock Windows value of a setting. It is never "the value the user had before Akari".
_Avoid_: original, previous value

**State**: what a Toggle's setting currently is on this machine: **Optimized** (matches what Apply sets), **Default** (matches stock Windows), **Custom** (readable, but neither of those) or **Unknown** (cannot be read).

**Risk**: how dangerous a Tweak is: **Safe**, **Caution** or **Advanced**. For a Choice it describes the Recommended value; other values may carry their own Risk.

**Choice**: a Tweak whose setting has more than two valid values, picked by the user (a service's start type, Win32PrioritySeparation). It has a Default and a Recommended value. Apply sets the Recommended value (or a value a Preset gives), and Revert sets the Default.
_Avoid_: tuner, dropdown, picker

**Recommended value**: the value Akari considers best for a Choice. A Choice whose value equals it is in the Optimized State.

## Organisation

**Section**: a top-level grouping of Tweaks: Optimize, Customize, Hardware (shown as "Graphics & Hardware"), Advanced and Tools (checks, Refresh, drivers, cleanup: Optimize › Advanced only). The Tweaks step shows one heading per Section, with its Categories under it.
_Avoid_: page, tab, category

**Category**: a group heading within a Section, such as Gaming under Optimize.

**Legacy**: the frozen AkariOS-Ultimate tweaks (the generated `Tweaks/*.ps1` files), shown on Optimize › Legacy with buttons that act right away. The port never edits or deletes them; `Tweaks/Ported.psd1` names the one-file Tweaks that replace each one (ADR 0004).
_Avoid_: old tweaks, Ultimate tweaks

**Catalogue**: Optimize › Advanced, every one-file Tweak on Section › Category pages, each change acting right away (ADR 0005). A Tweak with `Guided = $false` shows only there.
_Avoid_: manual page, all tweaks

**Requirement**: a condition a Tweak needs to make sense on a machine, such as Win11, NVIDIA or Desktop.

**USB setup file**: the `autounattend.xml` Akari writes for a Windows install USB (a Home tile): one local administrator, the chosen language and region, no setup questions. It is a tool, not a Tweak.
_Avoid_: answer file, unattend (in UI text)

## Running

**Run**: a single call to the engine with a list of Tweak ids, coming from the CLI, a Preset, or one Review & Apply in the GUI.

**Selection**: the changes picked in the Manual steps (Apply, Revert, a Choice value, or an Action to run). Nothing is applied while choosing; Review & Apply turns the Selection into one Run.
_Avoid_: pending list, cart

**Preset**: a named list of Tweak ids (a Choice may be given an explicit value; otherwise its Recommended value is used), optionally split into Phases. It is either **built-in** (shipped with Akari) or **user** (saved from the GUI).
_Avoid_: config, profile

**Phase**: one part of a Preset that runs in a specific boot mode (Normal or Safe Mode), with a reboot between Phases.

**Waiting for Safe Mode**: on the Catalogue, a SafeMode Tweak the user switched; it waits in a bar until "Restart and apply" starts one Run in phases for every waiting change.

**Outcome**: what happened to one Tweak in a Run: **Applied** or **Reverted** (done), **Already** (State already matched, nothing done), **Skipped** (a Requirement was not met) or **Failed** (an error occurred).

**Reboot pending**: set on a Run when at least one Tweak that needs a reboot was Applied or Reverted.

**Restore point**: a Windows System Restore point (described "AkariOS") that Akari creates before the first change of a GUI session in Install AkariOS (Guided, One-click), Optimize or Remove apps, never for Downloads. When one from an earlier session exists, the user is asked whether to make another.
