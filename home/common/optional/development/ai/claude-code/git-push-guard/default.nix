# Blocks `git push` from Claude unless ALLOW_GIT_PUSH is set, and makes setting it need approval.
{
  lib,
  pkgs,
  ...
}: {
  programs.claude-code-profiles = {
    extraPath = [
      (pkgs.writeShellApplication {
        name = "git";
        text = builtins.readFile ./git-shim.sh;
      })
    ];
    baseConfig.settings.hooks.PreToolUse = [
      {
        matcher = "Bash";
        hooks = [
          {
            type = "command";
            command = lib.getExe (pkgs.writeShellApplication {
              name = "claude-ask-on-push-override";
              runtimeInputs = with pkgs; [jq gnugrep];
              text = builtins.readFile ./ask-on-override.sh;
            });
          }
        ];
      }
    ];
  };
}
