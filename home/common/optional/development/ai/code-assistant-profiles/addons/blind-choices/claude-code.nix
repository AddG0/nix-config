# Seals the "(Recommended)" pick before the question is shown and reveals it after the answer.
{pkgs, ...}: let
  hook = import ./hooks.nix {inherit pkgs;};
  onAskUserQuestion = name: [
    {
      matcher = "AskUserQuestion";
      hooks = [
        {
          type = "command";
          command = "${hook name}/bin/blind-choices-${name}";
        }
      ];
    }
  ];
in {
  programs.claude-code-profiles.addons.blind-choices.settings.hooks = {
    PreToolUse = onAskUserQuestion "hide-pick";
    PostToolUse = onAskUserQuestion "reveal-pick";
  };
}
