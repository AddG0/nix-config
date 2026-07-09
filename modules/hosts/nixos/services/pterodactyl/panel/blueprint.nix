{lib, ...}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  #### ── interface ─────────────────────────────────────────────────────────────
  options.services.pterodactyl.panel.blueprint = {
    enable = mkEnableOption "Blueprint framework for Pterodactyl panel";

    themes = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Name of the theme";
          };
          version = mkOption {
            type = types.str;
            description = "Version of the theme";
          };
          source = mkOption {
            type = types.either types.str types.path;
            description = "Source URL or local path of the theme";
          };
        };
      });
      default = {};
      description = "Themes to install for Blueprint";
    };

    extensions = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            description = "Name of the extension";
          };
          version = mkOption {
            type = types.str;
            description = "Version of the extension";
          };
          source = mkOption {
            type = types.either types.str types.path;
            description = "Source URL or local path of the extension";
          };
        };
      });
      default = {};
      description = ''
        Blueprint extensions to bake into the panel package at build time
        (see buildPterodactylPanel in pkgs/pterodactyl-panel). No longer
        installed imperatively at runtime — the panel code is read-only.
      '';
    };
  };

  # Options only: extensions are baked into the panel package at build time
  # (see buildPterodactylPanel in pkgs/pterodactyl-panel), so there is nothing
  # to do at runtime — the panel code is read-only.
}
