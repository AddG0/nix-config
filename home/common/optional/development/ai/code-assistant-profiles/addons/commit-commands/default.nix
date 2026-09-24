{
  lib,
  inputs,
  ...
}: let
  pluginDir = "${inputs.claude-code}/plugins/commit-commands/commands";

  # Skills, not commands: only skills carry invocation, and these write git state.
  manualSkill = file: let
    cmd = lib.custom.ai.fromClaudeCommand file;
  in {
    inherit (cmd) description allowedTools;
    prompt.text = cmd.content.text;
    invocation.model = false;
  };
in {
  programs.code-assistant-profiles.addons.commit-commands = {
    skills = {
      "commit" = manualSkill "${pluginDir}/commit.md";
      "clean_gone" = manualSkill "${pluginDir}/clean_gone.md";
    };
  };
}
