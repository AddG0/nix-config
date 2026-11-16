# t3code from nixpkgs-unstable, which takes releases days before nixos-unstable;
# composed first so overlays/common/development/t3code patch this one.
#
# Held at 0.1.8 ahead of it: hubs read their management key through a secret
# provider only from 0.1.7, and read-secrets-from-commands/ needs that.
# Drop the override once `nix eval .#nixosConfigurations.demon.pkgs.unstable.t3code.version` is 0.1.8 or later.
_: final: _prev: {
  t3code = final.unstable.t3code.override {
    t3code-unwrapped = final.unstable.t3code.unwrapped.overrideAttrs (old: {
      version = "0.1.8";
      src = old.src.override {
        hash = "sha256-QPZpT/1zm5sLIDw3AOzUCIrmOFPwUU8jP/q1A8GzLow=";
      };
      pnpmDeps = old.pnpmDeps.overrideAttrs {
        outputHash = "sha256-ir2iMNpT5nA4ieTZT/7v5tawKH137DcfGFuzgxHfJjY=";
      };
    });
  };
}
