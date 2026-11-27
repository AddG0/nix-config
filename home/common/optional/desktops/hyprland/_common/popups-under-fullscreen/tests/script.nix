# Runs the REAL listener from ../listener.nix against stand-ins for socat and hyprctl. The cases are in ./popups-under-fullscreen.bats.
{
  pkgs,
  lib,
  harness,
  ...
}: let
  # Replays $EVENTS as the Hyprland event socket.
  socat = pkgs.writeShellScriptBin "socat" ''cat "$EVENTS"'';

  # Answers `-j clients` from $CLIENTS, or fails while $CLIENTS_FAIL is set; records each dispatch in $DISPATCHED and replies $DISPATCH_REPLY.
  hyprctl = pkgs.writeShellScriptBin "hyprctl" ''
    case "$1" in
      -j)
        if [ -n "''${CLIENTS_FAIL:-}" ]; then
          echo "couldn't connect to the Hyprland socket" >&2
          exit 1
        fi
        cat "$CLIENTS"
        ;;
      dispatch)
        shift
        echo "$*" >>"$DISPATCHED"
        echo "''${DISPATCH_REPLY:-ok}"
        ;;
      *)
        echo "unexpected hyprctl call: $*" >&2
        exit 2
        ;;
    esac
  '';

  listener = pkgs.callPackage ../listener.nix {
    hyprland = hyprctl;
    inherit socat;
  };
in
  harness.bats "popups-under-fullscreen-test" [./popups-under-fullscreen.bats] {
    nativeBuildInputs = [pkgs.jq];
    listener = lib.getExe listener;
  }
