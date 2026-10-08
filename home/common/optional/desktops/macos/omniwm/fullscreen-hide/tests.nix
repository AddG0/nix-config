# Planner cases for the fullscreen hide, run against hand-built OmniWM window snapshots.
#
# Auto-discovered and wired into `nix flake check` by checks/module-tests.nix.
{pkgs, ...}: let
  window = pid: workspace: attrs:
    {
      inherit pid;
      workspace.id = workspace;
      isFullscreen = false;
      isVisible = true;
      isAppHidden = false;
    }
    // attrs;
  event = windows:
    builtins.toJSON {
      channel = "windows-changed";
      result.payload.windows = windows;
    };
  ghostty = attrs: window 10 "ws1" attrs;
  t3 = window 20 "ws1" {};

  cases = {
    "hides the other apps on a visible fullscreen workspace" = {
      event = event [(ghostty {isFullscreen = true;}) t3 (window 30 "ws2" {isVisible = false;})];
      hidden = [];
      expect = {
        hide = [20];
        show = [];
        hidden = [20];
      };
    };
    "keeps an app hidden while its workspace stays fullscreen in the background" = {
      event = event [
        (ghostty {
          isFullscreen = true;
          isVisible = false;
        })
        (window 20 "ws1" {
          isAppHidden = true;
          isVisible = false;
        })
        (window 30 "ws2" {})
      ];
      hidden = [20];
      expect = {
        hide = [];
        show = [];
        hidden = [20];
      };
    };
    "ignores fullscreen windows on an inactive workspace" = {
      event = event [
        (ghostty {})
        t3
        (window 30 "ws2" {
          isFullscreen = true;
          isVisible = false;
        })
        (window 40 "ws2" {isVisible = false;})
      ];
      hidden = [];
      expect = {
        hide = [];
        show = [];
        hidden = [];
      };
    };
    "unhides what it hid once fullscreen ends" = {
      event = event [
        (ghostty {})
        (window 20 "ws1" {
          isAppHidden = true;
          isVisible = false;
        })
      ];
      hidden = [20];
      expect = {
        hide = [];
        show = [20];
        hidden = [];
      };
    };
    "does not re-hide an app the user brought back during fullscreen" = {
      event = event [(ghostty {isFullscreen = true;}) t3];
      hidden = [20];
      expect = {
        hide = [];
        show = [];
        hidden = [20];
      };
    };
    "leaves apps the user hid alone" = {
      event = event [
        (ghostty {isFullscreen = true;})
        (window 20 "ws1" {
          isAppHidden = true;
          isVisible = false;
        })
      ];
      hidden = [];
      expect = {
        hide = [];
        show = [];
        hidden = [];
      };
    };
    "does not treat windows without a workspace as sharing one" = {
      event = event [(window 10 null {isFullscreen = true;}) (window 20 null {})];
      hidden = [];
      expect = {
        hide = [];
        show = [];
        hidden = [];
      };
    };
    "keeps state through non-window events" = {
      event = builtins.toJSON {
        kind = "subscribe";
        result.kind = "subscribed";
      };
      hidden = [20];
      expect = {
        hide = [];
        show = [];
        hidden = [20];
      };
    };
  };

  runCase = name: c: ''
    actual=$(jq -cS --argjson hidden '${builtins.toJSON c.hidden}' -f ${./plan.jq} <<<'${c.event}')
    expected=$(jq -cS . <<<'${builtins.toJSON c.expect}')
    if [ "$actual" != "$expected" ]; then
      echo "FAIL: ${name}"; echo "  expected $expected"; echo "  actual   $actual"; failed=1
    else
      echo "ok: ${name}"
    fi
  '';
in
  pkgs.runCommand "omniwm-fullscreen-hide-tests" {nativeBuildInputs = [pkgs.jq];} ''
    failed=
    ${pkgs.lib.concatStrings (pkgs.lib.mapAttrsToList runCase cases)}
    [ -z "$failed" ]
    touch $out
  ''
