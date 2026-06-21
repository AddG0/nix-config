"""Clear the "Allow Notifications" bit for the Background Task Management agent.

Operates on a plist exported via `defaults export com.apple.ncprefs <file>`,
clearing bit 25 of the BTMNotificationAgent entry's `flags`. Writes back only if
a change is needed and exits 0; exits 1 (no-op) if the bit was already clear, so
the caller can skip the `defaults import` / `killall usernoted` round-trip.
"""

import plistlib
import sys

BUNDLE_ID = "com.apple.BTMNotificationAgent"
ALLOW_NOTIFICATIONS = 1 << 25

path = sys.argv[1]
with open(path, "rb") as f:
    prefs = plistlib.load(f)

changed = False
for app in prefs.get("apps", []):
    if app.get("bundle-id") == BUNDLE_ID:
        new_flags = int(app["flags"]) & ~ALLOW_NOTIFICATIONS
        if new_flags != app["flags"]:
            app["flags"] = new_flags
            changed = True
        break

if changed:
    with open(path, "wb") as f:
        plistlib.dump(prefs, f, fmt=plistlib.FMT_BINARY)

sys.exit(0 if changed else 1)
