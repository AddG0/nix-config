# `session-dpms off|on`: one idle config serves every compositor on the host, so pick the command at runtime.
{
  lib,
  pkgs,
  commands,
}: let
  cases = lib.concatStringsSep "\n" (lib.concatLists (lib.mapAttrsToList (desktop: c: [
      "    ${lib.escapeShellArg "${desktop}/off"}) exec ${c.off} ;;"
      "    ${lib.escapeShellArg "${desktop}/on"}) exec ${c.on} ;;"
    ])
    commands));
in
  pkgs.writeShellApplication {
    name = "session-dpms";
    text = ''
      state=''${1:-}
      case "$state" in
        off | on) ;;
        *)
          echo "session-dpms: expected off or on, got '$state'" >&2
          exit 2
          ;;
      esac

      current=''${XDG_CURRENT_DESKTOP:-}
      IFS=: read -ra desktops <<<"$current"
      for desktop in "''${desktops[@]}"; do
        case "$desktop/$state" in
      ${cases}
        esac
      done

      echo "session-dpms: no monitor power command for XDG_CURRENT_DESKTOP='$current'; known: ${lib.concatStringsSep ", " (lib.attrNames commands)}" >&2
      exit 1
    '';
  }
