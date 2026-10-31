# ReShade preset for Automobilista 2 (rig-pc)

## Goal

Automobilista 2 on rig-pc loads ReShade with H3RUS's "AMS2 Realistic" preset,
declared in Nix through steam-config-nix, without the preset file entering this
public repo.

## Non-goals

- ReShade for other games: none asked for yet.
- vkBasalt: partial ReShade shader support and no depth buffer, so presets need
  converting by hand.
- nix-reshade-manager: hooks in as a Vulkan layer, has no preset option and no
  users yet.

## Already staged

- `game-defaults [--gamescope] %command%`: the listed-game wrapper chain for
  unlisted games (`steam/game-defaults.nix`, test in `steam/tests/script.nix`).
- `automobilista-2 = 1066890` in `ids.nix`. `games.nix` sets
  `compatTool = defaultCompatTool`, because Steam's appinfo claims Linux and
  would run `AMS2.exe` natively, plus `wrappers = [gamemoderun] ++ gamescope`.
- None of it is built yet. Rebuild rig-pc, then launch from the Hyprland
  desktop to confirm the gamescope window appears. gamescope 3.16.31 with
  Hyprland 0.56.0 has a hidden-window bug (Hyprland #16410), and `-f` is the
  workaround the wrapper already passes.

## Design

Standard Windows ReShade under Proton, as done by
[reshade-steam-proton](https://github.com/kevinlekiller/reshade-steam-proton):
ReShade64.dll goes beside the exe as `dxgi.dll`, and the `dxgi=n,b` override
makes Wine load it first. ReShade then chains to Proton's DXVK dxgi.

On the `automobilista-2` entry in `games.nix`:

```nix
files.game.place = {
  "dxgi.dll".source = "${reshade}/…/ReShade64.dll";
  "d3dcompiler_47.dll".source = d3dcompiler47;
  "reshade-shaders".source = shaders; # DPX.fx, FakeHDR.fx, Levels.fx
  "ReShade.ini" = { source = ./ams2/ReShade.ini; mode = "seed"; };
  "AMS2 Realistic.ini" = { source = ams2Preset; mode = "seed"; };
};
dllOverrides = { dxgi = "n,b"; d3dcompiler_47 = "n"; };
```

- `seed` writes a file once and then leaves it alone, so tweaks made in the
  overlay survive rebuilds. The trade-off is that a preset change in Nix only
  lands after the file is deleted from the game folder.
- `dllOverrides`, not `env.WINEDLLOVERRIDES`: steam-config-nix rejects having both.

### The preset: `requireFile`

The download has no license, so only its hash goes in the repo.

- The file is `AMS2 Realistic.ini`, 546 bytes.
  - `sha256-7MSR3LwgyDD56cVT/mVH47ex2ADYfrZ67wzcrM111xo=`
  - base32: `06npfp6srp0cxxxbcznq03cb3dz38xjzwly5x7wk1j10pkf93i7c`
- Store names can't contain spaces, so `requireFile` uses
  `name = "ams2-realistic.ini"` and the copy is renamed before adding:
  `nix-store --add-fixed sha256 ams2-realistic.ini`, once on each machine that builds rig-pc.
- The preset enables `DPX@DPX.fx`, `HDR@FakeHDR.fx` and `Levels@Levels.fx`. Its
  other `TechniqueSorting` entries are ordering only.

## Open questions (in order)

1. **Shared library with two writers.** AMS2 installs into `/srv/steam-library`,
   and both `addg` and `gamer` get this config. steam-config-nix keeps its state
   per user (`$XDG_DATA_HOME/steam-config-nix`). A target that exists with no
   record of its own gets backed up once as a game file (`files.py`
   `_place_one`, `exists and prev is None`), so the second user would back up
   the first user's ReShade DLL. Reverting would then "restore" it. Choose
   between placing it for one user only and something else; read `files.py`
   `_revert_one` first.
2. **DirectX version.** AMS2 is expected to be DX11, so the DLL is `dxgi.dll`.
   Confirm on rig-pc: `d3d11.log`/`dxgi.log` in the game folder with
   `DXVK_LOG_PATH`, or `ReShade.log` after the first launch.
3. **Where ReShade comes from.** The
   [LovingMelody/nix-reshade](https://github.com/LovingMelody/nix-reshade) flake
   input already has `reshade` (no addons), `reshade-shaders` and
   `d3dcompiler_47-dll`. The alternative is our own `pkgs/by-name/reshade` that
   unpacks the reshade.me installer. Check nixpkgs first.
4. **Which shader pack has DPX, FakeHDR and Levels.** They are SweetFX shaders;
   confirm which `reshade-shaders` branch or package ships all three.
5. **Full game installed?** Only the demo was in `/srv/steam-library` on
   2026-10-30.

## Verification

- Test: a check that the `automobilista-2` app config places `dxgi.dll` and
  compiles `dxgi=n,b` into `WINEDLLOVERRIDES`.
- On rig-pc: `ReShade.log` appears beside `AMS2.exe`, and Home opens the
  overlay with "AMS2 Realistic" selectable. No log means Wine skipped ReShade.
