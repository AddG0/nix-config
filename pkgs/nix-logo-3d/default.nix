# Animated 3D nix snowflake for the nixvim dashboard, shipped as a plain nvim
# plugin. Consumed in home/common/core/nixvim/ui.nix.
{
  stdenvNoCC,
  chafa,
  imagemagick,
  python3,
  nixos-icons,
  # Grouped because callPackage fills any arg whose name matches a nixpkgs
  # attr, so a bare `tilt ? 18` would silently become pkgs.tilt.
  renderOpts ? {},
}: let
  opts =
    {
      # 96 at 16fps is one 6s sweep; more frames slows it, lower fps adds chop.
      frames = 96;
      fps = 16;
      # "spin" is a full revolution, which twice per turn flattens the plate.
      motion = "rock";
      # The grid the frames are encoded for; the section reserves rows lines.
      cols = 60;
      rows = 20;
      # Each fg/bg pair costs a highlight group: ~20k raw, ~1.1k at this level.
      quant = 16;
      # Point this at a recoloured copy to theme the logo.
      logo = "${nixos-icons}/share/icons/hicolor/1024x1024/apps/nix-snowflake.png";
    }
    // renderOpts;
in
  stdenvNoCC.mkDerivation {
    pname = "nix-logo-3d";
    version = "0.1.0";

    src = ./.;

    # Local package: src = ./. has no upstream URL for nix-update to bump.
    passthru.nixUpdate.version = "skip";

    nativeBuildInputs = [imagemagick python3 chafa];

    buildPhase = ''
      runHook preBuild

      MAGICK=magick FRAMES=${toString opts.frames} MOTION=${opts.motion} \
        python3 spin.py ${opts.logo} png

      CHAFA=chafa COLS=${toString opts.cols} ROWS=${toString opts.rows} \
        FPS=${toString opts.fps} QUANT=${toString opts.quant} \
        python3 luaify.py png lua/nix-logo-3d

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      install -Dm644 -t $out/lua/nix-logo-3d \
        lua/nix-logo-3d/init.lua lua/nix-logo-3d/frames.lua
      runHook postInstall
    '';

    meta.description = "Animated 3D nix snowflake for the snacks dashboard";
  }
