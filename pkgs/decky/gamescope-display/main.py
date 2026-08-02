"""Backend for the Display Settings plugin.

The work lives in gamescope-set-display, built by gaming/gamescope-session.
Resolved at runtime rather than baked in as a store path, so this stays a plain
derivation. The tool is deliberately not in systemPackages, so PATH only finds
it via decky-loader's own extraPackages.
"""

import asyncio
import os
import shutil

import decky

SET_DISPLAY = os.environ.get("GAMESCOPE_SET_DISPLAY") or shutil.which(
    "gamescope-set-display"
)

class ToolError(Exception):
    """gamescope-set-display could not be run, or exited non-zero."""


async def _run(*args: str) -> str:
    # None when neither the env var nor PATH resolved it, which would otherwise
    # surface as a TypeError the callers below do not catch.
    if not SET_DISPLAY:
        raise ToolError(
            "gamescope-set-display not found: GAMESCOPE_SET_DISPLAY is unset and "
            "it is not on PATH (decky-loader's extraPackages should provide it)"
        )

    proc = await asyncio.create_subprocess_exec(
        SET_DISPLAY,
        *args,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()
    if proc.returncode != 0:
        raise ToolError(
            f"gamescope-set-display {' '.join(args)} exited {proc.returncode}: "
            f"{stderr.decode(errors='replace').strip() or '(no stderr)'}"
        )
    return stdout.decode(errors="replace")


class Plugin:
    async def _main(self):
        decky.logger.info("display-settings ready (tool: %s)", SET_DISPLAY)

    async def _unload(self):
        pass

    async def load_displays(self) -> dict:
        """Connected displays in DRM order, and which one is stored.

        `id` identifies the panel by EDID and is what everything else here takes;
        `name` is only for showing. `preferred` is the head of the stored
        priority list, `active` what gamescope actually started on — they differ
        whenever the stored pick was unplugged. Both "" when unset.
        """
        try:
            listing = await _run("--list")
            stored = (await _run("--get")).strip()
            active = (await _run("--active")).strip()
        except (ToolError, OSError) as err:
            decky.logger.exception("listing displays failed")
            return {"ok": False, "error": str(err)}

        displays = []
        for line in listing.splitlines():
            fields = line.split("\t")
            if len(fields) != 3:
                continue
            ident, label, internal = fields
            displays.append(
                {"id": ident, "name": label, "internal": internal == "1"}
            )

        return {
            "ok": True,
            "displays": displays,
            "preferred": stored.split(",")[0] if stored else "",
            "active": active,
        }

    async def load_modes(self, display: str) -> dict:
        """What display `display` can do, and what is stored against it.

        Grouped for the two-dropdown picker: `resolutions` keeps DRM order and
        `refresh` maps each to its rates. `mode` is "" when the screen's own
        default is in use. `canVrr`/`canHdr` say whether the panel should offer
        those toggles at all — VRR especially is per-panel. All empty when the
        display is unplugged.
        """
        try:
            specs = (await _run("--modes", display)).split()
            stored = (await _run("--get-mode", display)).rstrip("\n")
            caps = (await _run("--caps", display)).split()
        except (ToolError, OSError) as err:
            decky.logger.exception("reading modes for %s failed", display)
            return {"ok": False, "error": str(err)}

        mode, _, flag_csv = stored.partition("\t")
        supported = dict(kv.split("=", 1) for kv in caps if "=" in kv)

        resolutions: list[str] = []
        refresh: dict[str, list[int]] = {}
        for spec in specs:
            res, _, hz = spec.partition("@")
            if not hz.isdigit():
                continue
            if res not in refresh:
                resolutions.append(res)
                refresh[res] = []
            refresh[res].append(int(hz))

        return {
            "ok": True,
            "resolutions": resolutions,
            "refresh": refresh,
            "mode": mode,
            "flags": [f for f in flag_csv.split(",") if f],
            "canVrr": supported.get("vrr") == "1",
            "canHdr": supported.get("hdr") == "1",
        }

    async def set_display(
        self, display: str, fallbacks: list[str], mode: str, flags: list[str]
    ) -> dict:
        """Record `display` (with the other connected ones behind it) and restart.

        `mode` is `WxH@Hz`, or "" to follow the display's own default, and
        `flags` holds "vrr"/"hdr". Both are written first because setting the
        display is what triggers the restart.

        `steam -shutdown` returns as soon as it has signalled Steam, so this
        replies while the session is still on its way down — ok here means the
        switch was accepted, not that it finished.
        """
        if not display:
            return {"ok": False, "error": "no display given"}

        order = ",".join([display] + [f for f in fallbacks if f != display])
        try:
            await _run("--mode", display, mode or "-", ",".join(flags) or "-")
            await _run(order)
        except (ToolError, OSError) as err:
            decky.logger.exception("switching to %s failed", display)
            return {"ok": False, "error": str(err)}

        return {"ok": True}

    async def clear_display(self) -> dict:
        """Drop the stored pick and restart on gamescope's own choice."""
        try:
            await _run("--clear")
        except (ToolError, OSError) as err:
            decky.logger.exception("clearing the stored display failed")
            return {"ok": False, "error": str(err)}

        return {"ok": True}
