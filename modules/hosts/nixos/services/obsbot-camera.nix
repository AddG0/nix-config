{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.obsbot-camera;
in {
  options.services.obsbot-camera = {
    enable = lib.mkEnableOption "Obsbot camera auto-configuration";

    devicePath = lib.mkOption {
      type = lib.types.str;
      default = "/dev/video0";
      description = "Path to the Obsbot camera device";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {
        pan_absolute = 20000;
        tilt_absolute = -50000;
        zoom_absolute = 10;
        focus_automatic_continuous = 1;
      };
      description = "Camera settings to apply when connected";
    };
  };

  config = lib.mkIf cfg.enable {
    services.udev.extraRules = ''
      # Obsbot camera auto-configuration
      # This rule triggers when any video device is added
      # You can make it more specific by adding ATTRS{name}=="Obsbot*" or similar
      ACTION=="add", SUBSYSTEM=="video4linux", KERNEL=="video0", RUN+="${pkgs.systemd}/bin/systemctl start obsbot-camera-setup.service"
    '';

    systemd.services.obsbot-camera-setup = {
      description = "Configure Obsbot camera settings";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = let
          settingsStr = lib.concatStringsSep "," (
            lib.mapAttrsToList (name: value: "${name}=${toString value}") cfg.settings
          );
        in "${pkgs.v4l-utils}/bin/v4l2-ctl -d ${cfg.devicePath} --set-ctrl=${settingsStr}";
      };
    };
  };
}
