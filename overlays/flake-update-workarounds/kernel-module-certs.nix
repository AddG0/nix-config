# aggregateModules now concatenates each module's kmodigest .ko.cer, but these
# packages copy their .ko by hand instead of running Kbuild's modules_install,
# so none is produced and the system build fails (nixpkgs#575192).
# v4l2loopback's modules_install also runs depmod, whose index files collide
# with the kernel's in aggregateModules.
# CHECK-RUNTIME: drop once nixpkgs installs openrazer and xpad-noone via
# modules_install, v4l2loopback ships no depmod indexes, and a rebuild without
# this overlay succeeds.
_: _final: prev: let
  sign = pkg:
    pkg.overrideAttrs (old: {
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ [prev.kmodigest];
      postInstall =
        (old.postInstall or "")
        + ''
          find "$out/lib/modules" -name '*.ko' -exec chmod u+w {} \; -exec kmodigest {} \;
        '';
    });
  dropDepmodIndexes = pkg:
    pkg.overrideAttrs (old: {
      postInstall =
        (old.postInstall or "")
        + ''
          rm -f "$out"/lib/modules/*/modules.*
        '';
    });
in {
  cachyosKernels =
    builtins.mapAttrs (
      _: set:
        if set ? extend
        then
          set.extend (_: kprev: {
            openrazer = sign kprev.openrazer;
            xpad-noone = sign kprev.xpad-noone;
            v4l2loopback = dropDepmodIndexes kprev.v4l2loopback;
          })
        else set
    )
    prev.cachyosKernels;
}
