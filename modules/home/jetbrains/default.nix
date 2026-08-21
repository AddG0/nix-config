{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.jetbrains;

  majorMinor = v: lib.concatStringsSep "." (lib.take 2 (lib.splitVersion v));

  configDirNames = {
    idea = "IntelliJIdea";
    pycharm = "PyCharm";
    datagrip = "DataGrip";
    webstorm = "WebStorm";
    phpstorm = "PhpStorm";
    clion = "CLion";
    goland = "GoLand";
    rider = "Rider";
    ruby-mine = "RubyMine";
    rust-rover = "RustRover";
  };

  configDirName = pkg:
    configDirNames.${pkg.pname}
    or (throw "Unknown JetBrains IDE '${pkg.pname}'. Add it to configDirNames in modules/home/jetbrains.");

  settingsSubmodule = lib.types.submodule {
    options = {
      theme = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Theme ID for the IDE look and feel.";
      };
      colorScheme = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Editor color scheme name.";
      };
      keymap = lib.mkOption {
        type = lib.types.nullOr (lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Keymap name (must be unique).";
            };
            parent = lib.mkOption {
              type = lib.types.str;
              description = "Parent keymap to inherit from.";
            };
            actions = lib.mkOption {
              type = lib.types.attrsOf (lib.types.listOf lib.types.str);
              default = {};
              description = "Action ID → list of keystroke strings. Empty list unbinds the action.";
            };
          };
        });
        default = null;
        description = "Custom keymap inheriting from a parent with action overrides.";
      };
      terminal.audibleBell = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to play a sound on terminal bell.";
      };
      ignoredFilePatterns = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Patterns to add to the IDE's ignored files and folders.";
      };
      extra = lib.mkOption {
        type = lib.types.attrsOf (lib.types.attrsOf lib.types.lines);
        default = {};
        description = "Escape hatch: raw settings files. Attrset of filename → component name → inner XML.";
      };
    };
  };

  ideSubmodule = lib.types.submodule {
    options = {
      package = lib.mkOption {
        type = lib.types.package;
        description = "The base JetBrains IDE package (used for pname lookup and config dir).";
      };
      plugins = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [];
        description = "Plugin derivations to install into the IDE.";
      };
      settings = lib.mkOption {
        type = settingsSubmodule;
        default = {};
        description = "IDE settings.";
      };
    };
  };

  platformKeymapDir =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "mac"
    else "linux";

  ideConfigRoot = ide: "JetBrains/${configDirName ide.package}${majorMinor ide.package.version}";

  componentXml = cname: inner: ''
    <component name="${cname}">
      ${inner}
    </component>'';

  mkSettingsXml = components: ''
    <application>
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList componentXml components)}
    </application>
  '';

  mkIdeFiles = _: ide: let
    s = ide.settings;
    root = ideConfigRoot ide;
    opt = "${root}/options";
  in
    lib.optionalAttrs (s.keymap != null) {
      "${opt}/${platformKeymapDir}/keymap.xml".text = mkSettingsXml {
        KeymapManager = ''<active_keymap name="${s.keymap.name}" />'';
      };
    }
    // lib.optionalAttrs (!s.terminal.audibleBell) {
      "${opt}/terminal.xml".text = mkSettingsXml {
        TerminalOptionsProvider = ''<option name="mySoundBell" value="false" />'';
        TerminalProjectOptionsProvider = ''<option name="mySoundBell" value="false" />'';
      };
    }
    // lib.mapAttrs' (filename: components: {
      name = "${opt}/${filename}";
      value.text = mkSettingsXml components;
    })
    s.extra;

  allFiles = lib.concatMapAttrs mkIdeFiles cfg.ides;

  # Merge script only needed for settings that share files with IDE-managed state.
  ideMergeConfigs =
    lib.mapAttrsToList (_: ide: {
      rootDir = "${config.xdg.configHome}/${ideConfigRoot ide}";
      packageDir = "${wrapIde ide}";
      inherit (ide.settings) ignoredFilePatterns;
      inherit (ide.settings) theme;
      inherit (ide.settings) colorScheme;
      keymap =
        if ide.settings.keymap == null
        then null
        else
          with ide.settings.keymap; {
            inherit name parent actions;
          };
    })
    cfg.ides;

  configJson = builtins.toJSON {ides = ideMergeConfigs;};

  # Hashed in too: a fix to how settings are written must break the stamp,
  # or the merge never re-runs.
  configHash = builtins.hashString "sha256" (configJson + builtins.hashFile "sha256" ./merge-settings.py);

  # Type=oneshot + RemainAfterExit only dedupes within a session, so without the
  # stamp every fresh login re-runs a ~15s merge that reads thousands of jars.
  mergeScript = pkgs.writeShellScript "jetbrains-settings-merge" ''
    set -eu
    statedir="''${XDG_STATE_HOME:-$HOME/.local/state}"
    stamp="$statedir/jetbrains-settings-merge.stamp"
    if [ "$(cat "$stamp" 2>/dev/null)" = "${configHash}" ]; then
      exit 0
    fi
    ${pkgs.python3}/bin/python3 ${./merge-settings.py} '${configJson}'
    mkdir -p "$statedir"
    printf '%s' "${configHash}" > "$stamp"
  '';

  hasMergeWork = lib.any (ide:
    ide.settings.ignoredFilePatterns
    != []
    || ide.settings.theme != null
    || ide.settings.colorScheme != null
    || ide.settings.keymap != null) (lib.attrValues cfg.ides);

  wrapIde = ide:
    if ide.plugins != []
    then pkgs.jetbrains.plugins.addPlugins ide.package ide.plugins
    else ide.package;
in {
  options.programs.jetbrains.ides = lib.mkOption {
    type = lib.types.attrsOf ideSubmodule;
    default = {};
    description = "JetBrains IDEs to manage settings for.";
  };

  config = lib.mkIf (cfg.ides != {}) (lib.mkMerge [
    {
      home.packages = lib.mapAttrsToList (_: wrapIde) cfg.ides;
      xdg.configFile = allFiles;
    }
    (lib.mkIf hasMergeWork {
      systemd.user.startServices = "sd-switch";
      systemd.user.services.jetbrains-settings-sync = {
        Unit.Description = "JetBrains settings merge [${configHash}]";
        Service = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = mergeScript;
        };
        Install.WantedBy = ["default.target"];
      };
    })
  ]);
}
