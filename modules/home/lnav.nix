# lnav (Logfile Navigator) module for Home Manager
# Configuration file location: ~/.config/lnav/config.json
# See: https://docs.lnav.org/en/stable/config.html
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.lnav;
  configDir =
    if (pkgs.stdenv.isDarwin && !config.xdg.enable)
    then "Library/Application Support/lnav"
    else "${config.xdg.configHome}/lnav";
in {
  options.programs.lnav = {
    enable = lib.mkEnableOption "lnav, the Logfile Navigator";

    package = lib.mkPackageOption pkgs "lnav" {};

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = ''
        Configuration settings for lnav in JSON format.
        
        Example:
        {
          tuning = {
            "archive-manager" = {
              "min-free-space" = 104857600;
              "cache-ttl" = "3d";
            };
            clipboard = {
              impls = {
                xclip = {
                  test = "command -v xclip";
                  general = {
                    write = "xclip -selection clipboard";
                    read = "xclip -selection clipboard -o";
                  };
                };
              };
            };
          };
        };
        
        Note: Attribute names with hyphens must be quoted in Nix.
      '';
      example = lib.literalExpression ''
        {
          tuning = {
            "archive-manager" = {
              "min-free-space" = 104857600;
              "cache-ttl" = "3d";
            };
          };
        };
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [cfg.package];

    home.file = {
      "${configDir}/config.json" = lib.mkIf (cfg.settings != {}) {
        text = builtins.toJSON cfg.settings;
      };
    };
  };
}
