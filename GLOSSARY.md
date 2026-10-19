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

**Apply**: perform a Tweak's change. In the GUI, turning a Toggle's switch On (or picking a Choice value) selects Apply; nothing happens until Review & Apply.
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

**Section**: a top-level grouping of Tweaks: Optimize, Customize, Hardware (shown as "Graphics & Hardware") and Advanced. The Tweaks step shows one heading per Section, with its Categories under it.
_Avoid_: page, tab, category

**Category**: a group heading within a Section, such as Gaming under Optimize.

**Requirement**: a condition a Tweak needs to make sense on a machine, such as Win11, NVIDIA or Desktop.

## Running

**Run**: a single call to the engine with a list of Tweak ids, coming from the CLI, a Preset, or one Review & Apply in the GUI.

**Selection**: the changes picked in the Manual steps (Apply, Revert, a Choice value, or an Action to run). Nothing is applied while choosing; Review & Apply turns the Selection into one Run.
_Avoid_: pending list, cart

**Preset**: a named list of Tweak ids (a Choice may be given an explicit value; otherwise its Recommended value is used), optionally split into Phases. It is either **built-in** (shipped with Akari) or **user** (saved from the GUI).
_Avoid_: config, profile

**Phase**: one part of a Preset that runs in a specific boot mode (Normal or Safe Mode), with a reboot between Phases.

**Outcome**: what happened to one Tweak in a Run: **Applied** or **Reverted** (done), **Already** (State already matched, nothing done), **Skipped** (a Requirement was not met) or **Failed** (an error occurred).

**Reboot pending**: set on a Run when at least one Tweak that needs a reboot was Applied or Reverted.

**Restore point**: a Windows System Restore point that Akari creates before the first change of a Run, or once per GUI session.
