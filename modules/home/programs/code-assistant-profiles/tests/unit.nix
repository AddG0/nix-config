# The shared profile model: resolving, validating and budgeting profiles; each target keeps its own tests beside its renderer.
{
  harness,
  lib,
  pkgs,
  ...
}: let
  fixtures = import ./_fixtures.nix {inherit harness lib pkgs;};
  inherit (import ./_areas.nix {inherit lib;}) areas;
in
  lib.genAttrs areas (area: import (./. + "/_${area}.nix") fixtures)
