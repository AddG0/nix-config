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
  harness.bats "claude-code-conditional-settings-test" [./wrapper.bats] {
    reachableWrapper = "${wrapper "exit 0"}/bin/claude";
    unreachableWrapper = "${wrapper "exit 1"}/bin/claude";
    slowWrapper = "${wrapper "sleep 6"}/bin/claude";
    pathWrapper = "${pathWrapper}/bin/claude";
    shadowedTool = "${shadowedTool}/bin/shadowed-tool";
  }
