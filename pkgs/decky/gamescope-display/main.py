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

# What gamescope itself counts as internal; only used to label the panel.
INTERNAL_PREFIXES = ("eDP", "LVDS", "DSI")


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
        """Connected connectors in DRM order, and which one is stored.

        `preferred` is the head of the stored priority list, or "" when unset.
        """
        try:
            names = (await _run("--list")).split()
            stored = (await _run("--get")).strip()
        except (ToolError, OSError) as err:
            decky.logger.exception("listing displays failed")
            return {"ok": False, "error": str(err)}

        return {
            "ok": True,
            "displays": [
                {"name": n, "internal": n.startswith(INTERNAL_PREFIXES)} for n in names
            ],
            "preferred": stored.split(",")[0] if stored else "",
        }

    async def load_modes(self, name: str) -> dict:
        """What `name` can do, and what is stored against it.

        Grouped for the two-dropdown picker: `resolutions` keeps DRM order and
        `refresh` maps each to its rates. `mode` is "" when the screen's own
        default is in use. `canVrr`/`canHdr` say whether the panel should offer
        those toggles at all — VRR especially is per-connector. All empty when
        the connector is gone.
        """
        try:
            specs = (await _run("--modes", name)).split()
            stored = (await _run("--get-mode", name)).rstrip("\n")
            caps = (await _run("--caps", name)).split()
        except (ToolError, OSError) as err:
            decky.logger.exception("reading modes for %s failed", name)
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
        self, name: str, fallbacks: list[str], mode: str, flags: list[str]
    ) -> dict:
        """Record `name` (with the other connected displays behind it) and restart.

        `mode` is `WxH@Hz`, or "" to follow the display's own default, and
        `flags` holds "vrr"/"hdr". Both are written first because setting the
        display is what triggers the restart.

        `steam -shutdown` returns as soon as it has signalled Steam, so this
        replies while the session is still on its way down — ok here means the
        switch was accepted, not that it finished.
        """
        if not name:
            return {"ok": False, "error": "no connector given"}

        order = ",".join([name] + [f for f in fallbacks if f != name])
        try:
            await _run("--mode", name, mode or "-", ",".join(flags) or "-")
            await _run(order)
        except (ToolError, OSError) as err:
            decky.logger.exception("switching to %s failed", name)
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
