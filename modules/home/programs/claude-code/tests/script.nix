# The claude wrapper: conditional settings, a caller's --settings, and its PATH.
{
  harness,
  lib,
  pkgs,
  ...
}: let
  fakeClaude = harness.stubs.claude;
  settingsFile = pkgs.writeText "conditional-settings.json" ''{"apiKeyHelper":"helper-token"}'';
  wrapper = command: tagging command null null;
  # `attributes` is the sessionAttributes command, or null for none.
  tagging = command: attributes: package:
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
        package =
          if package == null
          then fakeClaude
          else package;
        conditionalSettings = {
          command = lib.getExe (pkgs.writeShellScriptBin "settings-check" command);
          file = settingsFile;
        };
        sessionAttributes =
          if attributes == null
          then null
          else lib.getExe (pkgs.writeShellScriptBin "session-attributes" attributes);
      };
    }).wrapperScript;
  # Prints the resource attributes Claude Code would read, or "unset".
  envClaude = pkgs.writeShellScriptBin "claude" ''
    printf 'OTEL_RESOURCE_ATTRIBUTES=%s\n' "''${OTEL_RESOURCE_ATTRIBUTES-unset}"
  '';
  tagged = "echo \"ai_proxy.pool=$CLAUDE_SESSION_SETTINGS\"";
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
        sessionAttributes = null;
      };
    }).wrapperScript;
in
  harness.bats "claude-code-conditional-settings-test" [./wrapper.bats] {
    passingWrapper = "${wrapper "exit 0"}/bin/claude";
    failingWrapper = "${wrapper "exit 1"}/bin/claude";
    misconfiguredWrapper = "${wrapper "echo 'check: the config is broken' >&2; exit 2"}/bin/claude";
    unparsableWrapper = "${wrapper "echo '{not json'"}/bin/claude";
    printingWrapper = "${wrapper "echo '{\"env\":{\"EXAMPLE\":\"printed\"}}'"}/bin/claude";
    slowWrapper = "${wrapper "sleep 6"}/bin/claude";
    pathWrapper = "${pathWrapper}/bin/claude";
    taggedWrapper = "${tagging "exit 0" tagged envClaude}/bin/claude";
    taggedFailingWrapper = "${tagging "exit 1" tagged envClaude}/bin/claude";
    untaggableWrapper = "${tagging "exit 0" "exit 3" envClaude}/bin/claude";
    misconfiguredTaggingWrapper = "${tagging "exit 1" "echo 'tagger: the config is broken' >&2; exit 2" envClaude}/bin/claude";
    shadowedTool = "${shadowedTool}/bin/shadowed-tool";
  }
