# The scripts' shell logic: the shared helpers.sh, build-overlaid-packages.sh's verdict, and modpack.sh's Modrinth checks.
{
  harness,
  pkgs,
  ...
}:
harness.bats "scripts" [./helpers.bats ./build-overlaid-packages.bats ./modpack.bats] {
  nativeBuildInputs = [pkgs.jq];
  helpers = ../helpers.sh;
  buildOverlaidPackages = ../build-overlaid-packages.sh;
  modpack = ../modpack.sh;
}
