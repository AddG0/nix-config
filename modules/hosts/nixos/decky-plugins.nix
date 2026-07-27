# Declarative Decky Loader plugins and loader settings. Jovian has no such
# options — both are normally set imperatively via the Steam UI. The plugins
# dir is made authoritative: declared plugins are synced in and any other folder
# (e.g. a hand-installed plugin, or one dropped from this set) is pruned, so
# every host matches the config exactly. `settings` is deep-merged into
# loader.json each boot, so declared keys win over in-app changes while any
# undeclared keys Decky writes are preserved.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.jovian.decky-loader;

  overrides = (pkgs.formats.json {}).generate "decky-loader-overrides.json" cfg.settings;

  # Ordered before decky-loader so the seeded keys are present before the loader
  # reads them. jq `*` merges, so keys Decky owns (store-url, pluginOrder, …) survive.
  syncSettings = pkgs.writeShellApplication {
    name = "decky-settings-sync";
    runtimeInputs = [pkgs.coreutils pkgs.jq];
    text = ''
      settings_dir="${cfg.stateDir}/settings"
      loader="$settings_dir/loader.json"
      mkdir -p "$settings_dir"
      [ -f "$loader" ] || echo '{}' > "$loader"
      tmp="$(mktemp "$settings_dir/.loader.json.XXXXXX")"
      jq -s '.[0] * .[1]' "$loader" ${overrides} > "$tmp"
      mv "$tmp" "$loader"
      chown ${cfg.user}: "$loader"
    '';
  };

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

  options.jovian.decky-loader.settings = lib.mkOption {
    inherit ((pkgs.formats.json {})) type;
    default = {};
    example = lib.literalExpression "{ notificationSettings.pluginUpdates = false; }";
    description = ''
      Keys to deep-merge into the loader's `settings/loader.json` on each start.
      Declared keys override Decky's in-app values; undeclared keys are kept.
    '';
  };

  # `enable` is undefined on hosts without the jovian module; this file is auto-imported everywhere.
  config = lib.mkIf (cfg.enable or false) (lib.mkMerge [
    (lib.mkIf (cfg.plugins != {}) {
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
    })
    (lib.mkIf (cfg.settings != {}) {
      systemd.services = {
        decky-settings-sync = {
          description = "Provision declarative Decky Loader settings";
          wantedBy = ["multi-user.target"];
          before = ["decky-loader.service"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = lib.getExe syncSettings;
          };
        };

        # Re-apply settings (and restart the loader) when the overrides change.
        decky-loader.restartTriggers = [overrides];
      };
    })
  ]);
}
