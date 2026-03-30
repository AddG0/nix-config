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
    if pkgs.stdenv.isDarwin
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

  mkKeymapXml = km: ''
    <keymap version="1" name="${km.name}" parent="${km.parent}">
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (id: keys:
      if keys == []
      then ''<action id="${id}" />''
      else ''        <action id="${id}">
          ${lib.concatMapStringsSep "\n" (k: ''<keyboard-shortcut first-keystroke="${k}" />'') keys}
            </action>'')
    km.actions)}
    </keymap>'';

  mkIdeFiles = _: ide: let
    s = ide.settings;
    root = ideConfigRoot ide;
    opt = "${root}/options";
  in
    lib.optionalAttrs (s.theme != null) {
      "${opt}/laf.xml".text = mkSettingsXml {
        LafManager = ''<laf themeId="${s.theme}" />'';
      };
    }
    // lib.optionalAttrs (s.colorScheme != null) {
      "${opt}/colors.scheme.xml".text = mkSettingsXml {
        EditorColorsManagerImpl = ''<global_color_scheme name="${s.colorScheme}" />'';
      };
    }
    // lib.optionalAttrs (s.keymap != null) {
      "${root}/keymaps/${s.keymap.name}.xml".text = mkKeymapXml s.keymap;
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

  # Merge script only needed for ignoredFilePatterns
  ideIgnoreConfigs =
    lib.mapAttrsToList (_: ide: {
      configDir = "${config.xdg.configHome}/${ideConfigRoot ide}/options";
      inherit (ide.settings) ignoredFilePatterns;
    })
    cfg.ides;

  configJson = builtins.toJSON {ides = ideIgnoreConfigs;};

  mergeScript =
    pkgs.writeShellScript "jetbrains-settings-merge"
    ''${pkgs.python3}/bin/python3 ${./merge-settings.py} '${configJson}' '';

  settingsHash = builtins.hashString "sha256" (builtins.toJSON (lib.mapAttrsToList (_: ide: {
      inherit (ide.settings) ignoredFilePatterns;
      name = configDirName ide.package;
      inherit (ide.package) version;
    })
    cfg.ides));

  hasIgnoreWork = lib.any (ide: ide.settings.ignoredFilePatterns != []) (lib.attrValues cfg.ides);

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
    (lib.mkIf hasIgnoreWork {
      systemd.user.startServices = "sd-switch";
      systemd.user.services.jetbrains-settings-sync = {
        Unit.Description = "JetBrains ignored files merge [${settingsHash}]";
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
