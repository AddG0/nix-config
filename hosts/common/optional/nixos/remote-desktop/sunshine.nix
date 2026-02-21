# Moonlight client settings (macOS):
#   Resolution:     3840x2160
#   FPS:            60 (or 120 if display supports it)
#   Codec:          AV1 (best quality/bitrate, Apple Silicon HW decode)
#   YUV 4:4:4:     enabled (crisp text)
#   Bitrate:        60-80 Mbps (LAN), 20-30 Mbps (WAN)
#   Video decoder:  Hardware
#   Window mode:    Borderless (saves ~12ms vs fullscreen)
#   Mouse:          "Optimize mouse for remote desktop instead of games"
#
# Moonlight keybinds (Ctrl+Alt+Shift + key):
#   Z  Toggle mouse/keyboard capture
#   L  Lock mouse to window (needs remote desktop mouse mode)
#   M  Toggle mouse mode (capture vs direct)
#   X  Toggle fullscreen/windowed
#   D  Minimize
#   S  Show stream stats overlay
#   Q  Quit session
{pkgs, ...}: let
  hyprctl = "${pkgs.hyprland}/bin/hyprctl";
  jq = "${pkgs.jq}/bin/jq";
  stateFile = "/tmp/sunshine-monitors.json";

  sunshine-connect = pkgs.writeShellScript "sunshine-connect" ''
    # Save current physical monitor state (only if physical monitors exist)
    PHYSICAL=$(${hyprctl} -j monitors | ${jq} '[.[] | select(.name | test("^HEADLESS-") | not)]')
    if [ "$(echo "$PHYSICAL" | ${jq} 'length')" -gt 0 ]; then
      echo "$PHYSICAL" > ${stateFile}
    fi

    # Create headless output
    ${hyprctl} output create headless
    sleep 1

    # Find and configure it with client's requested resolution
    HEADLESS=$(${hyprctl} -j monitors | ${jq} -r '[.[] | select(.name | test("^HEADLESS-")).name] | first // empty')
    if [ -n "$HEADLESS" ]; then
      FPS=''${SUNSHINE_CLIENT_FPS:-60}
      ${hyprctl} keyword monitor "$HEADLESS,3840x2160@''${FPS},0x0,1"
    fi

    # Disable all physical monitors
    for MON in $(${jq} -r '.[] | select(.name | test("^HEADLESS-") | not).name' ${stateFile}); do
      ${hyprctl} keyword monitor "$MON,disable"
    done

    echo "Sunshine remote session active on $HEADLESS"
  '';

  sunshine-disconnect = pkgs.writeShellScript "sunshine-disconnect" ''
    # Restore physical monitors from saved state
    if [ -f ${stateFile} ]; then
      ${jq} -r '.[] | select(.name | test("^HEADLESS-") | not) | "\(.name),\(.width)x\(.height)@\(.refreshRate),\(.x)x\(.y),\(.scale),transform,\(.transform)"' ${stateFile} \
        | while IFS= read -r line; do
            ${hyprctl} keyword monitor "$line"
          done
      rm -f ${stateFile}
    fi

    # Remove all headless outputs
    for HEAD in $(${hyprctl} -j monitors | ${jq} -r '.[] | select(.name | test("^HEADLESS-")).name'); do
      ${hyprctl} output remove "$HEAD"
    done

    echo "Physical monitors restored"
  '';
in {
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true;
    openFirewall = true;
    package = pkgs.sunshine.override {cudaSupport = true;};
    settings = {
      # NVENC (RTX 5090)
      nvenc_preset = 1; # fastest, lowest latency
      nvenc_twopass = "quarter_res"; # better bitrate distribution
      nvenc_spatial_aq = "enabled"; # sharper text in flat regions
      nvenc_latency_over_power = "enabled";
      nvenc_vbv_increase = 300; # allow 3x bitrate burst on scene changes (default 100)

      # Quality — lower QP = higher quality (28 is default)
      qp = 20;

      # Keep encoding at stream FPS even when idle
      minimum_fps_target = 30;

      global_prep_cmd = builtins.toJSON [
        {
          do = "${sunshine-connect}";
          undo = "${sunshine-disconnect}";
        }
      ];
    };
  };

  # Make disconnect available as a command for the safety keybind
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "sunshine-disconnect" (builtins.readFile sunshine-disconnect))
  ];
}
