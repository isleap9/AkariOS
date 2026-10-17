# Revert goes to the stock Windows Default, not the previous value

Revert sets a Toggle or Choice back to the stock Windows value written in its tweak file, not to whatever the user had before Akari applied it. This keeps Akari stateless: Revert still works after a reinstall, on another machine, or when Akari never saw the earlier value. The cost is that a user who had their own value (a custom power plan, a hand-tuned `Win32PrioritySeparation`) loses it on Revert. The Restore point taken before each Run is the way back to "exactly what I had".

## Considered Options

- **Previous value**: snapshot before Apply, restore on Revert. Rejected: needs reliable persistent state per machine, and breaks when the snapshot is missing or stale.
- **Previous value if saved, else Default**: rejected, because the same button would behave differently depending on hidden history.
