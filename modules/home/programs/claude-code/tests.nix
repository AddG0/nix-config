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
  wrapperWith = memoryLimit: command:
    (import ./wrapper-script.nix {
      baseDir = ".config/claude-code/profiles";
      inherit lib pkgs;
      resolvedProfiles.default = {};
      cfg = {
        captureNode = null;
        unsetEnv = [];
        inherit memoryLimit;
        defaultProfile = "default";
        profiles.default = {};
        package = fakeClaude;
        conditionalSettings = {
          command = lib.getExe (pkgs.writeShellScriptBin "proxy-ready" command);
          file = proxySettings;
        };
      };
    }).wrapperScript;
  wrapper = wrapperWith null;
  limited = wrapperWith {
    high = null;
    max = "6G";
    swapMax = "1G";
  } "exit 1";
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

    grep -qF 'MemoryMax=6G' ${limited}/bin/claude
    grep -qF 'MemorySwapMax=1G' ${limited}/bin/claude
    if grep -qF MemoryHigh ${limited}/bin/claude; then
      echo "FAIL: null memoryLimit.high still throttles the session" >&2
      exit 1
    fi
    if grep -qF systemd-run ${wrapper "exit 1"}/bin/claude; then
      echo "FAIL: wrapper without memoryLimit still confines the session" >&2
      exit 1
    fi

    XDG_RUNTIME_DIR="$PWD/no-bus" ${limited}/bin/claude --version >nobus
    grep -qxF -- '--version' nobus

    touch "$out"
  ''
