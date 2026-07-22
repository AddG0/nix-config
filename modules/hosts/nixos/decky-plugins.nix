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
  # Staged in a sibling dir (not under plugins/) then mv'd in — atomic, and
  # Decky never scans a half-copied temp dir.
  syncPlugins = pkgs.writeShellApplication {
    name = "decky-plugin-sync";
    runtimeInputs = [pkgs.coreutils pkgs.findutils];
    text = ''
      plugins_dir="${cfg.stateDir}/plugins"
      staging="${cfg.stateDir}/.plugin-sync"
      declared="${lib.concatStringsSep " " (lib.attrNames cfg.plugins)}"
      mkdir -p "$plugins_dir" "$staging"
      ${lib.concatMapStringsSep "\n" (name: let
        drv = cfg.plugins.${name};
      in ''
        rm -rf "$staging/${name}"
        cp -rT --no-preserve=mode,ownership "${drv}" "$staging/${name}"
        rm -rf "$plugins_dir/${name}"
        mv "$staging/${name}" "$plugins_dir/${name}"
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

  # `enable` is undefined on hosts without the jovian module; this file is auto-imported everywhere.
  config = lib.mkIf ((cfg.enable or false) && cfg.plugins != {}) {
    systemd.services = {
      decky-plugin-sync = {
        description = "Provision declarative Decky Loader plugins";
        wantedBy = ["multi-user.target"];
        before = ["decky-loader.service"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = lib.getExe syncPlugins;
        };
      };

      # Reload plugin backends when the pinned set changes; otherwise a rebuild
      # syncs new files but decky-loader keeps running the old ones.
      decky-loader.restartTriggers = builtins.attrValues cfg.plugins;
    };
  };
}
