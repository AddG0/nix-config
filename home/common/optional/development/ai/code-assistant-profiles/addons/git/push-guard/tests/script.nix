# The push guard's hook, wrapper and shim, run against real git; the cases
# live in the .bats files beside this.
{
  harness,
  lib,
  pkgs,
  ...
}: let
  inherit (import ./_cases.nix {inherit harness lib pkgs;}) gitShim guardedSettings overrideReportingWrapper shellTools;
in
  harness.bats "git-push-guard-test" [./hook.bats ./shim.bats] {
    nativeBuildInputs = [pkgs.git pkgs.jq];
    inherit gitShim guardedSettings;
    shellToolsMatcher = lib.concatStringsSep "|" shellTools;
    overrideReportingWrapper = "${overrideReportingWrapper}/bin/claude";
  }
