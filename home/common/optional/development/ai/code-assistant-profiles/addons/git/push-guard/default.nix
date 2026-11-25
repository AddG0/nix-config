# Blocks `git push` from Claude unless ALLOW_GIT_PUSH=1, and makes setting it need approval.
{
  config,
  lib,
  pkgs,
  ...
}: {
  programs.claude-code-profiles = {
    # An override inherited from the launching shell would let every push past the shim unasked.
    unsetEnv = ["ALLOW_GIT_PUSH"];
    extraPath = [
      (pkgs.writeShellApplication {
        name = "git";
        # A fixed real git, not a PATH lookup: two shim builds on PATH would hand off to each other forever.
        text = "realGit=${lib.getExe config.programs.git.package}\n" + builtins.readFile ./git-shim.sh;
      })
    ];
    baseConfig.settings.hooks.PreToolUse = [
      {
        # Every tool that runs a shell command; Monitor shares Bash's environment and permission rules.
        matcher = "Bash|Monitor|PowerShell";
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
