{
  harness,
  pkgs,
  ...
}: let
  hooks = import ../hooks.nix {inherit pkgs;};
in
  harness.bats "code-standards-self-documenting-gate-test" [./gate.bats] {
    nativeBuildInputs = [pkgs.jq pkgs.git];
    baseline = "${hooks.baseline}/bin/self-documenting-baseline";
    gate = "${hooks.gate}/bin/self-documenting-gate";
    # Each .bats file reaches the store alone, so a relative load would miss it.
    scratchRepo = "${./_scratch-repo.bash}";
  }
