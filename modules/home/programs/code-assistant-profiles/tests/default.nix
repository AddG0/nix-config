# The shared profile model; each target keeps its own tests beside its renderer.
{
  pkgs,
  lib,
  ...
}: let
  fixtures = import ./fixtures.nix {inherit pkgs lib;};
  areas = ["resolve" "validation" "budgets" "structure" "launcher"];
in
  pkgs.runCommand "code-assistant-profiles-test" {} ''
    ${lib.concatMapStrings (area: import ./${area}.nix fixtures) areas}
    echo "code-assistant-profiles: resolver, validation, budget, structure and agent-run checks OK"
    touch "$out"
  ''
