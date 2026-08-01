"""Backend for the Gamescope Output plugin.

The work lives in gamescope-set-output, built by gaming/gamescope-session.nix.
Resolved at runtime rather than baked in as a store path, so this stays a plain
derivation; the fallbacks are there because a plugin subprocess may not inherit
the loader's environment.
"""

import asyncio
import os
import shutil

import decky

SET_OUTPUT = (
    os.environ.get("GAMESCOPE_SET_OUTPUT")
    or shutil.which("gamescope-set-output")
    or "/run/current-system/sw/bin/gamescope-set-output"
)

# What gamescope itself counts as internal; only used to label the panel.
INTERNAL_PREFIXES = ("eDP", "LVDS", "DSI")


class ToolError(Exception):
    """gamescope-set-output exited non-zero."""


async def _run(*args: str) -> str:
    proc = await asyncio.create_subprocess_exec(
        SET_OUTPUT,
        *args,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
    )
    stdout, stderr = await proc.communicate()
    if proc.returncode != 0:
        raise ToolError(
            f"gamescope-set-output {' '.join(args)} exited {proc.returncode}: "
            f"{stderr.decode(errors='replace').strip() or '(no stderr)'}"
        )
    return stdout.decode(errors="replace")


class Plugin:
    async def _main(self):
        decky.logger.info("gamescope-output ready (tool: %s)", SET_OUTPUT)

    async def _unload(self):
        pass

    async def list_outputs(self) -> dict:
        """Connected connectors, in DRM enumeration order."""
        try:
            names = (await _run("--list")).split()
        except (ToolError, OSError) as err:
            decky.logger.exception("listing outputs failed")
            return {"ok": False, "error": str(err)}

        return {
            "ok": True,
            "outputs": [
                {"name": n, "internal": n.startswith(INTERNAL_PREFIXES)} for n in names
            ],
        }

    async def get_preferred(self) -> dict:
        """First name of the stored priority list, or "" when unset."""
        try:
            stored = (await _run("--get")).strip()
        except (ToolError, OSError) as err:
            decky.logger.exception("reading the stored output failed")
            return {"ok": False, "error": str(err)}

        return {"ok": True, "preferred": stored.split(",")[0] if stored else ""}

    async def set_output(self, name: str, fallbacks: list[str]) -> dict:
        """Record `name` (with the other connected outputs behind it) and restart.

        `steam -shutdown` returns as soon as it has signalled Steam, so this
        replies while the session is still on its way down — ok here means the
        switch was accepted, not that it finished.
        """
        if not name:
            return {"ok": False, "error": "no connector given"}

        order = ",".join([name] + [f for f in fallbacks if f != name])
        try:
            await _run(order)
        except (ToolError, OSError) as err:
            decky.logger.exception("switching to %s failed", name)
            return {"ok": False, "error": str(err)}

        return {"ok": True}

    async def clear_output(self) -> dict:
        """Drop the stored pick and restart on gamescope's own choice."""
        try:
            await _run("--clear")
        except (ToolError, OSError) as err:
            decky.logger.exception("clearing the stored output failed")
            return {"ok": False, "error": str(err)}

        return {"ok": True}
