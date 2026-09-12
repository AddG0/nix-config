# Blackmagic re-uploaded the 21.1 Linux build on 2026-09-10 under a new CDN path
# (v21.1-1) without changing the version string, so nixpkgs' pinned src hash no
# longer matches what the download endpoint serves.
#
# The hash lives on the inner `davinci` derivation's src, which the FHS wrapper
# closes over, so `overrideAttrs` can't reach it. `runCommandLocal` builds only
# that src, so overriding the argument is enough.
#
# `home/common/optional/media/davinci-resolve.nix` takes the package from the
# `unstable` set, which is imported without overlays, hence the second patch.
# CHECK-ATTR: davinci-resolve-studio
_: _final: prev: let
  newSrcHash = "sha256-P+zu8/OuFcDcIkwV3UMq0qg9U2JEGRkKDP+VLQesZjw=";

  fixSrcHash = pkgs: drv:
    drv.override {
      runCommandLocal = name: env: cmd:
        pkgs.runCommandLocal name (env // {outputHash = newSrcHash;}) cmd;
    };
in
  prev.lib.optionalAttrs (prev ? davinci-resolve-studio) {
    davinci-resolve-studio = fixSrcHash prev prev.davinci-resolve-studio;

    unstable =
      prev.unstable
      // {
        davinci-resolve-studio = fixSrcHash prev.unstable prev.unstable.davinci-resolve-studio;
      };
  }
