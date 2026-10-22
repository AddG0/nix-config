# The shared model's unit areas: every `_<area>.nix` here that is not a helper.
{lib}: let
  helpers = ["_areas.nix" "_fixtures.nix" "_validators.nix"];
  areasOf = entries: map (name: lib.removePrefix "_" (lib.removeSuffix ".nix" name)) (lib.filter (name: entries.${name} == "regular" && lib.hasPrefix "_" name && lib.hasSuffix ".nix" name && !lib.elem name helpers) (lib.attrNames entries));
in {
  inherit areasOf helpers;
  areas = areasOf (builtins.readDir ./.);
}
