# The scripts' shell logic: the shared helpers.sh, and build-overlaid-packages.sh's verdict.
{
  harness,
  pkgs,
  ...
}:
harness.bats "scripts" [./helpers.bats ./build-overlaid-packages.bats] {
  nativeBuildInputs = [pkgs.jq];
  helpers = ../helpers.sh;
  buildOverlaidPackages = ../build-overlaid-packages.sh;
}
