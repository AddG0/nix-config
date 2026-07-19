# Declarative Decky Loader plugins. Jovian has no such option — plugins are
# normally installed imperatively via the Steam UI. The plugins dir is made
# authoritative: declared plugins are synced in and any other folder (e.g. a
# hand-installed plugin, or one dropped from this set) is pruned, so every host
# matches the config exactly. The loader's settings dir is never touched.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.jovian.decky-loader;

  # Ordered before decky-loader but NOT required by it, so a provisioning
  # failure leaves the last good copy on disk and the loader still starts.
  # tmp-then-mv keeps each plugin's swap atomic.
  syncPlugins = pkgs.writeShellApplication {
    name = "decky-plugin-sync";
    runtimeInputs = [pkgs.coreutils pkgs.findutils];
    text = ''
      plugins_dir="${cfg.stateDir}/plugins"
      declared="${lib.concatStringsSep " " (lib.attrNames cfg.plugins)}"
      mkdir -p "$plugins_dir"
      ${lib.concatMapStringsSep "\n" (name: let
        drv = cfg.plugins.${name};
      in ''
        rm -rf "$plugins_dir/.${name}.new"
        cp -rT --no-preserve=mode,ownership "${drv}" "$plugins_dir/.${name}.new"
        rm -rf "$plugins_dir/${name}"
        mv "$plugins_dir/.${name}.new" "$plugins_dir/${name}"
      '') (lib.attrNames cfg.plugins)}
      find "$plugins_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | while read -r f; do
        case " $declared " in
          *" $f "*) ;;
          *) rm -rf "''${plugins_dir:?}/$f" ;;
        esac
      done
      chown -R ${cfg.user}: "$plugins_dir"
    '';
  };
in {
  options.jovian.decky-loader.plugins = lib.mkOption {
    type = lib.types.attrsOf lib.types.package;
    default = {};
    example = lib.literalExpression "{ Deckcord = pkgs.deckcord; }";
    description = ''
      Decky Loader plugins to provision declaratively: an attribute set from
      plugin name (the folder Decky sees) to a package whose root is the
      plugin's contents (plugin.json at the top level). Synced into
      `''${stateDir}/plugins/<name>` on each start; the dir is authoritative,
      so undeclared folders (hand-installed plugins) are pruned and Decky's
      in-app "update" won't stick since the pinned version is re-applied.
    '';
  };

  config = lib.mkIf (cfg.enable && cfg.plugins != {}) {
    systemd.services.decky-plugin-sync = {
      description = "Provision declarative Decky Loader plugins";
      wantedBy = ["multi-user.target"];
      before = ["decky-loader.service"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe syncPlugins;
      };
    };
  };
}
