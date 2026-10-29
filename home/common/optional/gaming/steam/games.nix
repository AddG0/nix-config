# Per-game Steam settings by slug, over the defaults default.nix applies; app IDs live in ids.nix.
{
  defaultCompatTool,
  gamemoderun,
  gamescope,
  gamescopeHdr,
  mouseDpi,
  requireController,
  bakkesLauncher,
}: {
  # Rocket League has a linux build, but it's not maintained so we need to use the windows version
  rocket-league.compatTool = defaultCompatTool;
  # Inert unless Steam's "Anti-Cheat Disabled" launch option is selected — a
  # manual choice; BakkesMod cannot inject into the EAC executable.
  rocket-league.wrappers = [(requireController "Rocket League") gamemoderun] ++ bakkesLauncher;
  portal-2 = {
    # I had multiplayer issues with the linux version. So I'm using the windows version.
    compatTool = defaultCompatTool;
    # Had some issues with resolution not being correct or having an option to make it correct
    wrappers = [gamemoderun] ++ gamescope;
    # 32-bit D3D9: DXVK's 100 MB texture-mapping budget remaps textures on the main thread mid-game.
    env.DXVK_CONFIG = "d3d9.textureMemory = 0";
  };
  # Wouldn't let me install if this wasn't set
  conan-exiles.compatTool = defaultCompatTool;
  # Was not opening with linux version
  aimlabs.compatTool = defaultCompatTool;

  # Gamescope wrap: HZD's native fullscreen on Linux/Proton is broken
  # (wrong resolution, multi-monitor misbehavior, alt-tab loss).
  # Gamescope forces a sane fullscreen surface and fixes it.
  horizon-zero-dawn.wrappers = [gamemoderun] ++ gamescope;

  aimlabs.wrappers = mouseDpi 1600 ++ [gamemoderun];

  # Wrap in gaemscope to fix weird fullscreen behavior
  forza-horizon-4.wrappers = [gamemoderun] ++ gamescopeHdr;
  forza-horizon-5.wrappers = [gamemoderun] ++ gamescopeHdr;
  forza-horizon-6.wrappers = [gamemoderun] ++ gamescopeHdr;

  # Wine's Wayland driver: an XWayland window can't carry HDR.
  overwatch.wrappers = mouseDpi 1800 ++ [gamemoderun "env" "PROTON_ENABLE_WAYLAND=1"];

  # 2000 DPI + in-game sens 2 reproduces the Aim Lab cm/360 (0.52% off).
  cyberpunk-2077.wrappers = mouseDpi 2000 ++ [gamemoderun];

  # Bigscreen Beyond Utility — Windows-only app for adjusting the
  # headset's fan, brightness, refresh rate, and LED color.
  # Intentionally minimal: PROTON_ENABLE_HIDRAW is documented but
  # appears to make things worse on Proton 10.x / Experimental
  # (BeyondHID logs "parent not found" with it set). The first
  # successful detection at 14:06 happened with no override at all.
  # https://github.com/ValveSoftware/Proton/issues/8672
}
