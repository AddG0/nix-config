{
  harness,
  pkgs,
  ...
}:
harness.bats "documentation-write-for-people-gate-test" [./write-for-people-gate.bats] {
  nativeBuildInputs = [pkgs.jq];
  gate = "${import ../hooks.nix {inherit pkgs;}}/bin/documentation-write-for-people-gate";
}
