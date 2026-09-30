# Our pkgs/ scope under one namespaced attr; patch it with `addg = prev.addg.overrideScope (…)`.
_: final: _prev: {
  addg = import ../pkgs/packages.nix final;
}
