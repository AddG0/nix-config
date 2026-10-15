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
  inherit
    (import ./resolve-profile.nix {
      inherit lib;
      cfg = {};
    })
    mergeConfigs
    ;
  settingsOf = base: overlay: (mergeConfigs {settings = base;} {settings = overlay;}).settings;
  hook = matcher: {
    inherit matcher;
    hooks = [{command = matcher;}];
  };

  # Pure, so a failure throws while the check evaluates.
  mergeFailures = lib.runTests {
    testHooksForOneEventFromTwoSourcesBothSurvive = {
      expr = (settingsOf {hooks.PreToolUse = [(hook "Bash")];} {hooks.PreToolUse = [(hook "AskUserQuestion")];}).hooks.PreToolUse;
      expected = [(hook "Bash") (hook "AskUserQuestion")];
    };
    testPermissionListsFromTwoSourcesBothSurvive = {
      expr = (settingsOf {permissions.allow = ["Edit"];} {permissions.allow = ["Edit(docs/**)"];}).permissions.allow;
      expected = ["Edit" "Edit(docs/**)"];
    };
    testAnEntryBothSourcesDeclareIsKeptOnce = {
      expr = (settingsOf {permissions.deny = ["Read(./.env)"];} {permissions.deny = ["Read(./.env)"];}).permissions.deny;
      expected = ["Read(./.env)"];
    };
    testAScalarFromTheOverlayStillWins = {
      expr = (settingsOf {model = "a";} {model = "b";}).model;
      expected = "b";
    };
  };
in
  lib.throwIf (mergeFailures != [])
  "claude-code settings merge tests failed:\n${lib.generators.toPretty {} mergeFailures}"
  pkgs.runCommand "claude-code-conditional-settings-test" {} ''
    export HOME="$PWD/home"
    mkdir -p "$HOME/.config/claude-code/profiles/default"

    ${wrapper "exit 0"}/bin/claude >reachable
    grep -qx -- '--settings' reachable
    grep -qx -- '${proxySettings}' reachable

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

    timeout 4s ${wrapper "sleep 6"}/bin/claude --version >version
    grep -qxF -- '--version' version

    touch "$out"
  ''
