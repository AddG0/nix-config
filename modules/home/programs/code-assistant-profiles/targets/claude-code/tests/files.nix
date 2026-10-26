# Bad configs only Claude Code's own validators reject, as a home's build runs them, and a claude whose doctor output changed.
{
  lib,
  pkgs,
  self,
  ...
}: let
  inherit (import ../../../tests/_validators.nix {inherit lib pkgs self;}) validatorRejection;

  # A claude whose doctor words a bad setting differently from the one the validator was written against.
  rewordedClaude = pkgs.writeShellScriptBin "claude" ''
    if [[ $1 == doctor ]]; then
      printf 'Claude Code doctor\nSettings problems\n - permissions.defaultMode: Invalid value\n'
    fi
  '';
  profileDir = ".config/claude-code/profiles/default";
  reworded = pkgs.testers.testBuildFailure (import ../../../run-validators.nix {inherit pkgs lib;} {
    name = "fixture-reworded";
    homes.t = {
      programs.code-assistant-profiles.validators.claude-code =
        import ../validator.nix {
          inherit lib;
          config.programs.claude-code-profiles = {
            enable = true;
            package = rewordedClaude;
            profiles.default = {inherit profileDir;};
          };
        }
        // {
          extraDirs = [];
          mergedFiles = [];
        };
      home = {
        homeDirectory = "/home/t";
        file.settings = {
          enable = true;
          target = "${profileDir}/settings.json";
          source = pkgs.writeText "settings.json" "{}";
        };
      };
      xdg.configHome = "/home/t/.config";
    };
  });

  rejectedByValidator = {
    claude-settings = {
      module = {programs.claude-code-profiles.profiles.default.settings.permissions.defaultMode = lib.mkForce "bogus";};
      expected = ["fixture-claude-settings: claude-code: .config/claude-code/profiles/default/settings.json: `claude doctor`" "permissions.defaultMode: Invalid value"];
    };
  };
in
  pkgs.runCommand "code-assistant-profiles-claude-code-files" {} ''
    ${lib.concatStrings (lib.mapAttrsToList validatorRejection rejectedByValidator)}
    if ! grep -qF "fixture-reworded: claude-code: canary settings.json: \`claude doctor\` rejected it" ${reworded}/testBuildFailure.log || ! grep -qF "can no longer be read" ${reworded}/testBuildFailure.log; then
      echo "FAIL: a claude whose doctor no longer says 'Invalid settings' passed the settings check:" >&2
      cat ${reworded}/testBuildFailure.log >&2
      exit 1
    fi
    touch "$out"
  ''
