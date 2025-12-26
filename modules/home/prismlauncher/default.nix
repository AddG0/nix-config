# Prism Launcher module for Home Manager
# Declarative instances with auto-updating packwiz modpacks
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption mkIf mkMerge types mapAttrsToList concatStringsSep literalExpression optionalString;

  cfg = config.programs.prismlauncher;

  # Import submodules
  loaderComponents = import ./loaders.nix;
  prismLib = import ./lib.nix {inherit lib;};
  scripts = import ./scripts.nix {inherit pkgs;};

  inherit (prismLib) validateInstanceName parsePackToml resolveIcon;

  # Directories
  packwizDir = "${config.home.homeDirectory}/.local/share/packwiz";
  prismDir = "${config.home.homeDirectory}/.local/share/PrismLauncher";

  # Packwiz installer bootstrap
  packwizBootstrap = pkgs.fetchurl {
    url = "https://github.com/packwiz/packwiz-installer-bootstrap/releases/download/v0.0.3/packwiz-installer-bootstrap.jar";
    sha256 = "sha256-qPuyTcYEJ46X9GiOgtPZGjGLmO/AjV2/y8vKtkQ9EWw=";
  };

  # Resolve modpack config (merge parsed pack.toml with user overrides)
  resolveModpack = name: modpack: let
    validName = validateInstanceName name;
    parsed = parsePackToml modpack.source;
    iconResolved = resolveIcon modpack.icon;
  in {
    name = validName;
    inherit (modpack) source group javaArgs mutableOverrides;
    icon = iconResolved.key;
    iconPath = iconResolved.path;
    iconIsCustom = iconResolved.isCustom;
    mcVersion =
      if modpack.mcVersion != null
      then modpack.mcVersion
      else parsed.mcVersion;
    loader =
      if modpack.loader != null
      then modpack.loader
      else parsed.loader;
    loaderVersion =
      if modpack.loaderVersion != null
      then modpack.loaderVersion
      else parsed.loaderVersion;
  };

  # Generate mmc-pack.json content
  mkMmcPackJson = modpack:
    builtins.toJSON {
      formatVersion = 1;
      components =
        [
          {
            uid = "net.minecraft";
            version = modpack.mcVersion;
            important = true;
          }
        ]
        ++ loaderComponents.${modpack.loader} modpack.mcVersion modpack.loaderVersion;
    };

  # Generate instance.cfg content
  mkInstanceCfg = name: modpack: ''
    [General]
    ConfigVersion=1.2
    InstanceType=OneSix
    iconKey=${modpack.icon}
    name=${name}
    OverrideCommands=true
    PreLaunchCommand=\"$INST_JAVA\" -jar \"${packwizDir}/packwiz-installer-bootstrap.jar\" \"file://${packwizDir}/${name}/pack.toml\"
    ${optionalString (modpack.javaArgs != null) ''
      OverrideJavaArgs=true
      JvmArgs=${modpack.javaArgs}
    ''}
  '';

  # Modpack submodule options
  modpackOpts = {
    options = {
      source = mkOption {
        type = types.path;
        description = "Path to packwiz modpack directory containing pack.toml";
      };

      mcVersion = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "1.20.1";
        description = "Minecraft version (auto-detected from pack.toml if not set)";
      };

      loader = mkOption {
        type = types.nullOr (types.enum ["fabric" "quilt" "forge" "neoforge"]);
        default = null;
        description = "Mod loader (auto-detected from pack.toml if not set)";
      };

      loaderVersion = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "0.15.6";
        description = "Mod loader version (auto-detected from pack.toml if not set)";
      };

      icon = mkOption {
        type = types.either types.str types.path;
        default = "default";
        example = literalExpression "./icons/my-pack.png";
        description = ''
          Instance icon. Can be either:
          - A string key for built-in icons (e.g., "default", "diamond", "flame")
          - A path to a custom icon file (png, jpg, svg, ico, webp)

          Custom icons are automatically installed to Prism's icons folder.
        '';
      };

      group = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "Modded";
        description = "Instance group for organization in Prism Launcher";
      };

      javaArgs = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "-Xmx4G -Xms2G";
        description = "JVM arguments for this instance";
      };

      mutableOverrides = mkOption {
        type = types.bool;
        default = true;
        description = ''
          If true (default), overrides are only copied if they don't exist.
          If false, overrides are merged/copied on every rebuild.
        '';
      };
    };
  };

  # Collect custom icons
  customIcons = lib.filterAttrs (_: v: v != null) (
    lib.mapAttrs' (_: modpack: let
      resolved = resolveIcon modpack.icon;
    in
      lib.nameValuePair resolved.key (
        if resolved.isCustom
        then resolved.path
        else null
      ))
    cfg.modpacks
  );

  # Collect instance groups
  instanceGroups =
    lib.foldlAttrs
    (acc: name: modpack:
      if modpack.group != null
      then
        acc
        // {
          ${modpack.group} = (acc.${modpack.group} or []) ++ [name];
        }
      else acc)
    {}
    cfg.modpacks;

  # Generate instgroups.json content
  instGroupsJson = builtins.toJSON {
    formatVersion = "1";
    groups =
      lib.mapAttrs (_: instances: {
        hidden = false;
        inherit instances;
      })
      instanceGroups;
  };

  # Generate instance setup scripts
  instanceSetups = mapAttrsToList (name: modpack: let
    resolved = resolveModpack name modpack;
  in
    scripts.mkInstanceSetup {
      inherit name prismDir packwizDir;
      inherit (resolved) mutableOverrides;
      mmcPackJson = mkMmcPackJson resolved;
      instanceCfg = mkInstanceCfg name resolved;
    })
  cfg.modpacks;

  managedInstancesStr = concatStringsSep " " (builtins.attrNames cfg.modpacks);
in {
  options.programs.prismlauncher = {
    enable = mkEnableOption "Prism Launcher with packwiz modpacks";

    package = mkOption {
      type = types.package;
      default = pkgs.prismlauncher;
      description = "Prism Launcher package";
    };

    cleanupOrphans = mkOption {
      type = types.bool;
      default = true;
      description = "Remove instances that were managed by this module but are no longer in config";
    };

    modpacks = mkOption {
      type = types.attrsOf (types.submodule modpackOpts);
      default = {};
      description = "Modpack definitions (versions auto-detected from pack.toml)";
      example = literalExpression ''
        {
          "my-pack" = {
            source = ./modpacks/my-pack;
            icon = ./icons/my-pack.png;
            group = "Modded";
            javaArgs = "-Xmx4G";
          };
        }
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      cfg.package
      pkgs.packwiz
    ];

    home.file = mkMerge [
      # Packwiz bootstrap jar
      {"${packwizDir}/packwiz-installer-bootstrap.jar".source = packwizBootstrap;}

      # Packwiz modpack files
      (mkMerge (mapAttrsToList (name: modpack: {
          "${packwizDir}/${name}" = {
            inherit (modpack) source;
            recursive = true;
          };
        })
        cfg.modpacks))

      # Custom icons
      (mkMerge (mapAttrsToList (key: path: {
          "${prismDir}/icons/${key}${
            lib.optionalString (builtins.match ".*\\.[^.]+$" (toString path) != null) (let
              filename = builtins.baseNameOf (toString path);
              ext = lib.last (lib.splitString "." filename);
            in ".${ext}")
          }".source =
            path;
        })
        customIcons))
    ];

    # Create writable instance files and manage groups
    home.activation.setupPrismInstances = lib.hm.dag.entryAfter ["writeBoundary"] ''
      ${optionalString cfg.cleanupOrphans (scripts.mkCleanupScript {inherit prismDir managedInstancesStr;})}
      ${concatStringsSep "\n" instanceSetups}
      ${scripts.mkUpdateGroupsScript {inherit prismDir instGroupsJson;}}
    '';
  };
}
