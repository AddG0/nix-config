# The claude wrapper: conditional proxy settings, a caller's --settings, and its PATH.
{
  harness,
  lib,
  pkgs,
  ...
}: let
  fakeClaude = harness.stubs.claude;
  proxySettings = pkgs.writeText "proxy-settings.json" ''{"apiKeyHelper":"proxy-token"}'';
  wrapper = command:
    (import ../wrapper-script.nix rec {
      baseDir = ".config/claude-code/profiles";
      inherit lib pkgs;
      pluginCheck = import ../plugin-check.nix {inherit cfg lib pkgs;};
      resolvedProfiles.default = {};
      cfg = {
        captureNode = null;
        checkConfig = true;
        unsetEnv = [];
        extraPath = [];
        defaultProfile = "default";
        profiles.default = {};
        package = fakeClaude;
        conditionalSettings = {
          command = lib.getExe (pkgs.writeShellScriptBin "proxy-ready" command);
          file = proxySettings;
        };
      };
    }).wrapperScript;
  shadowedTool = pkgs.writeShellScriptBin "shadowed-tool" "";
  pathWrapper =
    (import ../wrapper-script.nix rec {
      baseDir = ".config/claude-code/profiles";
      inherit lib pkgs;
      pluginCheck = import ../plugin-check.nix {inherit cfg lib pkgs;};
      resolvedProfiles.default = {};
      cfg = {
        captureNode = null;
        checkConfig = true;
        unsetEnv = [];
        extraPath = [shadowedTool];
        defaultProfile = "default";
        profiles.default = {};
        package = pkgs.writeShellScriptBin "claude" "command -v shadowed-tool";
        conditionalSettings = null;
      };
    }).wrapperScript;
in
  pkgs.runCommand "claude-code-conditional-settings-test" {} ''
    export HOME="$PWD/home"
    mkdir -p "$HOME/.config/claude-code/profiles/default"

    ${wrapper "exit 0"}/bin/claude >reachable
    grep -qx -- '--settings' reachable
    grep -qxF '{"apiKeyHelper":"proxy-token"}' reachable

    ${wrapper "exit 0"}/bin/claude --settings '{"showThinkingSummaries":true}' -p hi >merged
    if [ "$(grep -cx -- '--settings' merged)" != 1 ]; then
      echo "FAIL: caller --settings not merged into the session settings" >&2
      cat merged >&2
      exit 1
    fi
    grep -qxF '{"apiKeyHelper":"proxy-token","showThinkingSummaries":true}' merged
    grep -qx -- '-p' merged

    echo '{"model":"opus"}' >caller.json
    ${wrapper "exit 0"}/bin/claude --settings=caller.json >merged-file
    grep -qxF '{"apiKeyHelper":"proxy-token","model":"opus"}' merged-file

    if ${wrapper "exit 0"}/bin/claude --settings missing.json 2>missing-err; then
      echo "FAIL: unreadable caller --settings did not abort" >&2
      exit 1
    fi
    grep -qF 'cannot merge --settings missing.json' missing-err

    ${wrapper "exit 1"}/bin/claude --settings '{"showThinkingSummaries":true}' >passthrough
    grep -qxF '{"showThinkingSummaries":true}' passthrough

    ${wrapper "exit 1"}/bin/claude >unreachable
    if [ -s unreachable ]; then
      echo "FAIL: unreachable proxy still added session settings" >&2
      cat unreachable >&2
      exit 1
    fi

    ${pathWrapper}/bin/claude >shadowed
    grep -qxF '${shadowedTool}/bin/shadowed-tool' shadowed

    timeout 4s ${wrapper "sleep 6"}/bin/claude --version >version
    grep -qxF -- '--version' version

    touch "$out"
  ''
