# Holds back commands that post text until write-for-people has loaded; semantic routing alone misses it when another skill owns the flow.
{pkgs, ...}: let
  gate = [
    {
      type = "command";
      command = "${import ./hooks.nix {inherit pkgs;}}/bin/documentation-write-for-people-gate";
    }
  ];
in {
  programs.claude-code-profiles.addons.documentation.settings.hooks = {
    PreToolUse = [
      {
        matcher = "Bash";
        hooks = gate;
      }
    ];
    PostToolUse = [
      {
        matcher = "Skill";
        hooks = gate;
      }
    ];
    SessionStart = [
      {
        matcher = "compact";
        hooks = gate;
      }
    ];
  };
}
