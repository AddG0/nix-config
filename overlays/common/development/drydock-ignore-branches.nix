# Adds `status.ignore_branches`: CI rebuilds `nightly`, so every local copy reads
# as unpushed. Drop if upstream (yetidevworks/drydock) grows the same option.
_: _final: prev: {
  addg = prev.addg.overrideScope (_: aprev: {
    drydock = aprev.drydock.overrideAttrs (o: {
      patches = (o.patches or []) ++ [./drydock-ignore-branches.patch];
    });
  });
}
