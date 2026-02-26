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
  # Thin wrappers that exec the user's XDG config scripts.
  # The actual scripts are managed by home-manager (desktops/hyprland/sunshine).
  prep = cmd:
    pkgs.writeShellScript "sunshine-${cmd}" ''
      SCRIPT="''${XDG_CONFIG_HOME:-$HOME/.config}/sunshine/${cmd}"
      [ -x "$SCRIPT" ] && exec "$SCRIPT"
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
          do = "${prep "connect"}";
          undo = "${prep "disconnect"}";
        }
      ];
    };
  };
}
