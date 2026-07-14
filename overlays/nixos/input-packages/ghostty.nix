# Pin ghostty to the upstream flake. Its darwin output has no `default`
# package (the macOS app is built via Xcode, not nix — see
# home/common/optional/ghostty which uses pkgs.ghostty-bin on darwin), so this
# overlay lives under overlays/nixos and is auto-guarded to Linux by
# overlays/default.nix.
{inputs, ...}: _final: prev: {
  ghostty = inputs.ghostty.packages.${prev.stdenv.hostPlatform.system}.default;
}
