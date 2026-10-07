# Auto-discovered and wired into `nix flake check` by checks/module-tests.nix.
{
  pkgs,
  lib,
  ...
}: let
  fakeClaude = pkgs.writeShellScriptBin "claude" ''
    if (( $# )); then
      printf '%s\n' "$@"
    fi
  '';
  proxySettings = pkgs.writeText "proxy-settings.json" ''{"apiKeyHelper":"proxy-token"}'';
  wrapper = command:
    (import ./wrapper-script.nix {
      baseDir = ".config/claude-code/profiles";
      inherit lib pkgs;
      resolvedProfiles.default = {};
      cfg = {
        captureNode = null;
        unsetEnv = [];
        defaultProfile = "default";
        profiles.default = {};
        package = fakeClaude;
        conditionalSettings = {
          command = lib.getExe (pkgs.writeShellScriptBin "proxy-ready" command);
          file = proxySettings;
        };
      };
    }).wrapperScript;
in
  pkgs.runCommand "claude-code-conditional-settings-test" {} ''
    export HOME="$PWD/home"
    mkdir -p "$HOME/.config/claude-code/profiles/default"

    ${wrapper "exit 0"}/bin/claude >reachable
    grep -qx -- '--settings' reachable
    grep -qx -- '${proxySettings}' reachable

    ${wrapper "exit 1"}/bin/claude >unreachable
    if [ -s unreachable ]; then
      echo "FAIL: unreachable proxy still added session settings" >&2
      cat unreachable >&2
      exit 1
    fi

    timeout 4s ${wrapper "sleep 6"}/bin/claude --version >version
    grep -qxF -- '--version' version

    touch "$out"
  ''
