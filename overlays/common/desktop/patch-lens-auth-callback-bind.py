#!/usr/bin/env python3
"""Rebind Lens's OIDC auth callback server from "localhost" to 127.0.0.1.

Substitution is equal-length so app.asar's header offsets stay valid and the
archive needs no repack. Anchored on the auth injectable's id so the GKE
loopback server (same call shape, separate flow) is left alone.
"""

import pathlib
import sys

ANCHOR = b"start-auth-callback-server"
OLD = b'listen(0,"localhost")'
NEW = b'listen(0,"127.0.0.1")'

# The bind sits ~500 bytes past the anchor; a big jump means the bundle was
# restructured and this patch needs re-deriving rather than silently moving.
MAX_ANCHOR_DISTANCE = 2000


def main(path: str) -> None:
    asar = pathlib.Path(path)
    data = bytearray(asar.read_bytes())
    original_len = len(data)

    if len(OLD) != len(NEW):
        sys.exit(f"refusing: replacement changes length ({len(OLD)} -> {len(NEW)})")

    found = data.count(OLD)
    if found != 2:
        sys.exit(f"expected 2 {OLD!r} call sites (auth + GKE), found {found}")

    anchor = data.find(ANCHOR)
    if anchor == -1:
        sys.exit(f"anchor {ANCHOR!r} not found in app.asar")

    site = data.find(OLD, anchor)
    if site == -1:
        sys.exit(f"no {OLD!r} call site after anchor {ANCHOR!r}")
    if site - anchor > MAX_ANCHOR_DISTANCE:
        sys.exit(f"call site {site - anchor} bytes past anchor; bundle layout changed")

    data[site : site + len(OLD)] = NEW

    if len(data) != original_len:
        sys.exit("refusing: file length changed")
    if data.count(OLD) != 1:
        sys.exit("expected exactly 1 remaining (GKE) call site after patching")

    asar.write_bytes(bytes(data))
    print(f"lens: rebound auth callback server to 127.0.0.1 at offset {site}")


if __name__ == "__main__":
    main(sys.argv[1])
