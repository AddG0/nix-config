# programs.hyprland now setcaps bin/Hyprland, and ensure-wrapper-integrity rejects
# it as a bash script: hy3's pinned Hyprland wraps with makeWrapper, while upstream
# main (and nixpkgs) already use makeBinaryWrapper. Drops once hy3 bumps past that.
# CHECK-RUNTIME: drop once `grep makeBinaryWrapper nix/default.nix` matches in hy3's pinned hyprland input.
_: final: prev:
prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
  hyprland = prev.hyprland.overrideAttrs (old: {
    nativeBuildInputs =
      builtins.filter (p: (p.name or "") != "make-shell-wrapper-hook") old.nativeBuildInputs
      ++ [final.makeBinaryWrapper];
  });
}
