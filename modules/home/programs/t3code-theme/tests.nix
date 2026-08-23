# Drives the real generated boot script against a localStorage stub — otherwise
# the only signal is whether t3code happens to come up themed.
#
# Auto-discovered and wired into `nix flake check` by checks/module-tests.nix.
{
  pkgs,
  lib,
  ...
}: let
  themeId = "stylix";

  bootScript = import ./boot-script.nix {
    inherit pkgs;
    theme = {
      id = themeId;
      label = "Stylix";
      appearance = "dark";
      colors = {
        canvas = "#1e1e2e";
        text = "#cdd6f4";
        accent = "#89b4fa";
      };
    };
  };
in
  pkgs.runCommand "t3code-boot-script" {
    nativeBuildInputs = [pkgs.nodejs];
  } ''
    node ${./boot-script-test.mjs} ${lib.escapeShellArg bootScript} ${themeId} | tee $out
  ''
