# t3code from nixpkgs-unstable, which takes releases days before nixos-unstable;
# composed first so overlays/common/development/t3code patch this one.
_: final: _prev: {
  inherit (final.unstable) t3code;
}
