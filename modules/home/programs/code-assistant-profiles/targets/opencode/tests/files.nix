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
      expected = ["fixture-opencode-colour: opencode: .config/opencode: `opencode-config-check" "opencode dropped these agent files" "  painter"];
    };
    opencode-setting = {
      module = {programs.opencode.settings.model = 5;};
      expected = ["fixture-opencode-setting: opencode: .config/opencode: `opencode-config-check" "opencode reported these configuration problems:" "opencode.json $.model: skipped malformed recognized value"];
    };
    opencode-skill-yaml = {
      module = {programs.opencode.skills.broken = "---\nname: [unclosed\ndescription: Broken\n---\nBody.\n";};
      expected = ["fixture-opencode-skill-yaml: opencode: .config/opencode/skills: `opencode-skill-check" "opencode skipped these skill files:" "broken/SKILL.md reason=markdown"];
    };
  };
in
  pkgs.runCommand "code-assistant-profiles-opencode-files" {} ''
    ${lib.concatStrings (lib.mapAttrsToList validatorRejection rejectedByValidator)}
    touch "$out"
  ''
