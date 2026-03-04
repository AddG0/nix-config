# Hyprland-specific Sunshine integration: virtual monitor management + Noctalia notification redirection.
# Scripts are placed in ~/.config/sunshine/ and executed by the NixOS Sunshine service via global_prep_cmd.
# Monitor layout is baked at build time from config.monitors — no runtime state needed.
{
  config,
  lib,
  pkgs,
  ...
}: let
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  jq = "${pkgs.jq}/bin/jq";

  hyprLib = import ./lib.nix;
  transformToHyprland = hyprLib.transformMap;
  vrrToHyprland = hyprLib.vrrMap;

  monitorNames = map (m: m.name) config.monitors;
  primaryNames = map (m: m.name) (builtins.filter (m: m.primary) config.monitors);

  disableMonitors = lib.concatMapStringsSep "\n" (name: ''
    ${hyprctl} keyword monitor "${name},disable"'')
  monitorNames;

  restoreMonitors = lib.concatMapStringsSep "\n" (m: ''
    ${hyprctl} keyword monitor "${m.name},${toString m.width}x${toString m.height}@${toString m.refreshRate}.0,${toString m.x}x${toString m.y},1,transform,${toString transformToHyprland.${m.transform}},vrr,${toString vrrToHyprland.${m.vrr}}${
      if m.bitdepth != 8
      then ",bitdepth,${toString m.bitdepth}"
      else ""
    }${
      if m.hdr
      then ",cm,hdr"
      else ""
    }"'')
  config.monitors;

  primaryJson = builtins.toJSON primaryNames;
  primaryMon = builtins.head primaryNames;

  # Parse workspace rules like "1, monitor:DP-3, default:true" → { ws, mon }
  wsRules = let
    rules = config.wayland.windowManager.hyprland.settings.workspace or [];
    parseRule = rule: let
      parts = lib.splitString "," rule;
      wsId = lib.trim (builtins.head parts);
      monPart = lib.findFirst (p: lib.hasPrefix "monitor:" (lib.trim p)) null (builtins.tail parts);
      mon =
        if monPart != null
        then lib.removePrefix "monitor:" (lib.trim monPart)
        else null;
    in
      if mon != null
      then {
        ws = wsId;
        inherit mon;
      }
      else null;
  in
    builtins.filter (x: x != null) (map parseRule rules);

  configuredWsIds = map (r: r.ws) wsRules;

  moveConfiguredWs = lib.concatMapStringsSep "\n" (r: ''
    ${hyprctl} dispatch moveworkspacetomonitor ${r.ws} ${r.mon}'')
  wsRules;

  # Bash case pattern for configured workspace IDs (e.g. "1|2|3")
  configuredPattern = lib.concatStringsSep "|" configuredWsIds;

  nocSettings = "\${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/noctalia/settings.json";

  sunshine-connect = pkgs.writeShellApplication {
    name = "sunshine-connect";
    runtimeInputs = [pkgs.hyprland pkgs.jq];
    text = ''
      # Create headless output
      hyprctl output create headless
      sleep 1

      HEADLESS=$(hyprctl -j monitors | jq -r '[.[] | select(.name | test("^HEADLESS-")).name] | first // empty')
      if [ -z "$HEADLESS" ]; then
        echo "Error: no headless monitor found" >&2
        exit 1
      fi

      FPS=''${SUNSHINE_CLIENT_FPS:-60}
      hyprctl keyword monitor "$HEADLESS,3840x2160@''${FPS},0x0,1"

      # Disable physical monitors
      ${disableMonitors}

      # Redirect Noctalia notifications to headless monitor
      NOC_SETTINGS="${nocSettings}"
      if [ -f "$NOC_SETTINGS" ]; then
        ${jq} --arg mon "$HEADLESS" '.notifications.monitors = [$mon]' "$NOC_SETTINGS" > "$NOC_SETTINGS.tmp" \
          && mv "$NOC_SETTINGS.tmp" "$NOC_SETTINGS"
      fi

      echo "Sunshine session active on $HEADLESS"
    '';
  };

  sunshine-disconnect = pkgs.writeShellApplication {
    name = "sunshine-disconnect";
    runtimeInputs = [pkgs.hyprland pkgs.jq];
    text = ''
      # Restore physical monitors
      ${restoreMonitors}
      sleep 2

      # Move configured workspaces back to their monitors
      ${moveConfiguredWs}

      # Move any remaining workspaces to primary monitor
      for ws in $(hyprctl -j workspaces | jq -r '.[].id'); do
      ${
        if configuredWsIds != []
        then ''          case "$ws" in
                    ${configuredPattern}) ;; # already moved
                    *) hyprctl dispatch moveworkspacetomonitor "$ws" "${primaryMon}" ;;
                  esac''
        else ''hyprctl dispatch moveworkspacetomonitor "$ws" "${primaryMon}"''
      }
      done

      # Restore Noctalia notifications to primary monitors
      NOC_SETTINGS="${nocSettings}"
      if [ -f "$NOC_SETTINGS" ]; then
        ${jq} --argjson monitors '${primaryJson}' '.notifications.monitors = $monitors' "$NOC_SETTINGS" > "$NOC_SETTINGS.tmp" \
          && mv "$NOC_SETTINGS.tmp" "$NOC_SETTINGS"
      fi

      # Remove headless outputs
      for HEAD in $(hyprctl -j monitors | jq -r '.[] | select(.name | test("^HEADLESS-")).name'); do
        hyprctl output remove "$HEAD"
      done

      echo "Physical monitors restored"
    '';
  };
in {
  xdg.configFile = {
    "sunshine/connect".source = "${sunshine-connect}/bin/sunshine-connect";
    "sunshine/disconnect".source = "${sunshine-disconnect}/bin/sunshine-disconnect";
  };

  home.packages = [sunshine-disconnect];
}
