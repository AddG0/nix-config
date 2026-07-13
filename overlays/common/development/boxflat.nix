# Boxflat: silence the "needs to update udev rules" alert. The rule is installed
# declaratively via services.udev.packages = [pkgs.boxflat], so boxflat's in-app
# rules-version check (which lives in mutable ~/.config/boxflat/settings.yml) is
# a false positive on NixOS. --replace-fail intentionally — if upstream changes
# this line the build breaks loudly and we revisit.
_: _final: prev: {
  boxflat = prev.boxflat.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace boxflat/app.py \
          --replace-fail \
            'if udev_exists and rules_version >= 2:' \
            'if True:  # NixOS: udev rules installed declaratively'
      '';
  });
}
