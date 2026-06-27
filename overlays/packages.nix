# Custom packages from pkgs/packages.nix, merged into nixpkgs namespaces.
_: _final: prev: let
  customPkgs = import ../pkgs/packages.nix prev;

  # If the name already exists in nixpkgs, merge attrsets (or preserve a
  # callable namespace via __functor); otherwise just add it.
  mergePackage = name: value:
    if builtins.hasAttr name prev
    then
      if builtins.isAttrs value && builtins.isAttrs prev.${name}
      then prev.${name} // value
      else if builtins.isFunction prev.${name} && builtins.isAttrs value
      then value // {__functor = _self: prev.${name};}
      else value
    else value;
in
  builtins.mapAttrs mergePackage customPkgs
