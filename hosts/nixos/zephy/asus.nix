{
  pkgs,
  lib,
  ...
}: {
  systemd.user.services."asus-keyboard-light" = {
    description = "Set ASUS keyboard lights at startup";
    wantedBy = ["default.target"];
    serviceConfig = {
      ExecStart = "${pkgs.asusctl}/bin/asusctl -k high && ${pkgs.asusctl}/bin/asusctl aura rainbow-wave";
    };
  };

  services = {
    asusd = {
      enable = lib.mkDefault true;
      enableUserService = true;

      # Aggressive fan curves for better cooling during gaming
      # Prevents thermal throttling by ramping fans faster and hitting max at lower temps
      # Format: (temp_celsius, pwm_0-255) - MUST have exactly 8 points
      fanCurvesConfig = {
        text = ''
          (
            profiles: (
              balanced: [
                (
                  fan: CPU,
                  pwm: (26, 77, 127, 153, 178, 217, 242, 255),
                  temp: (30, 40, 50, 55, 60, 70, 80, 85),
                  enabled: true,
                ),
                (
                  fan: GPU,
                  pwm: (26, 77, 127, 153, 178, 217, 242, 255),
                  temp: (30, 40, 50, 55, 60, 70, 80, 85),
                  enabled: true,
                ),
              ],
              performance: [
                (
                  fan: CPU,
                  pwm: (89, 115, 153, 178, 191, 230, 255, 255),
                  temp: (30, 40, 50, 55, 60, 68, 75, 80),
                  enabled: true,
                ),
                (
                  fan: GPU,
                  pwm: (89, 115, 153, 178, 204, 242, 255, 255),
                  temp: (30, 40, 50, 55, 60, 65, 70, 75),
                  enabled: true,
                ),
              ],
              quiet: [
                (
                  fan: CPU,
                  pwm: (13, 38, 64, 102, 153, 204, 242, 255),
                  temp: (30, 40, 50, 60, 70, 80, 90, 95),
                  enabled: true,
                ),
                (
                  fan: GPU,
                  pwm: (13, 38, 64, 102, 153, 204, 242, 255),
                  temp: (30, 40, 50, 60, 70, 80, 90, 95),
                  enabled: true,
                ),
              ],
              custom: [],
            ),
          )
        '';
      };

      # ASUS profile AC/battery configuration
      # WARNING: This only works with power-profiles-daemon v0.10.0+
      # We use TLP instead of power-profiles-daemon (see power-management.nix)
      # Currently using power-state-manager.asus backend as alternative
      # To use this: enable power-profiles-daemon, disable TLP, uncomment below
      # profileConfig = {
      #   text = ''
      #     (
      #       active_profile: Balanced,
      #       fan_curve_enabled: true,
      #       mini_led_mode: false,
      #       profile_on_mains: Balanced,
      #       profile_on_battery: Quiet,
      #     )
      #   '';
      # };
    };

    asus-numberpad-driver = {
      enable = true;
      layout = "gx551"; # Layout for Zephyrus Duo models
    };
  };
}
