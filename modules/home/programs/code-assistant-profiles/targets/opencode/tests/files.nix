# Bad configs only opencode's own validators reject.
{
  lib,
  pkgs,
  self,
  ...
}: let
  inherit (import ../../../tests/_validators.nix {inherit lib pkgs self;}) validatorRejection;

  rejectedByValidator = {
    opencode-colour = {
      module = {programs.opencode.agents.painter = "---\ndescription: Paints\ncolor: red\n---\nPaint.\n";};
      expected = ["fixture-opencode-colour: opencode: .config/opencode: `opencode debug config`" ''got "red" color''];
    };
  };
in
  pkgs.runCommand "code-assistant-profiles-opencode-files" {} ''
    ${lib.concatStrings (lib.mapAttrsToList validatorRejection rejectedByValidator)}
    touch "$out"
  ''
