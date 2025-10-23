# Define greetd options globally for consistent availability, regardless of greetd configuration import
{ config, pkgs, lib, ... }:
{
  options.services.greetd = {
    sessionCommand = lib.mkOption {
      type = lib.types.str;
      default = "${pkgs.hyprland}/bin/Hyprland";
      description = "Command to run for session";
    };

    username = lib.mkOption {
      type = lib.types.str;
      default = config.hostSpec.username;
      description = "Username for greetd session";
    };

    autoLogin = {
      enable = lib.mkEnableOption "Enable automatic login";
      username = lib.mkOption {
        type = lib.types.str;
        default = config.services.greetd.username;
        description = "User to automatically login";
      };
    };
  };
}
