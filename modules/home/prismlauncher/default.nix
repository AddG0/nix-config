# Prism Launcher Packwiz Extension for Home Manager
# Extends upstream programs.prismlauncher with declarative packwiz modpack support
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkOption mkIf mkMerge types mapAttrsToList concatStringsSep literalExpression optionalString;

  cfg = config.programs.prismlauncher;
  hasModpacks = cfg.modpacks != {};

  # Import submodules
  loaderComponents = import ./loaders.nix;
  prismLib = import ./lib.nix {inherit lib;};
  scripts = import ./scripts.nix {inherit pkgs;};

  inherit (prismLib) validateInstanceName parsePackToml resolveIcon;

  # Resolve a world entry to { folderName, storePath }
  resolveWorld = worldName: world: let
    hasSource = world.source != null;
    hasUrl = world.url != null;
    storePath =
      if hasSource && hasUrl
      then throw "World '${worldName}': 'source' and 'url' are mutually exclusive"
      else if hasSource
      then world.source
      else if hasUrl
      then
        if world.hash == null
        then throw "World '${worldName}': 'hash' is required when using 'url'"
        else
          pkgs.fetchzip {
            inherit (world) url hash;
          }
      else throw "World '${worldName}': either 'source' or 'url' must be set";
  in {
    folderName =
      if world.folderName != null
      then world.folderName
      else worldName;
    inherit storePath;
  };

  # Generate shell script to install world saves for an instance
  mkWorldSetupScript = instanceName: worlds: let
    savesDir = "${prismDir}/instances/${instanceName}/.minecraft/saves";
    worldScripts =
      mapAttrsToList (_: world: ''
        if [ ! -d ${lib.escapeShellArg "${savesDir}/${world.folderName}"} ]; then
          run cp -r ${lib.escapeShellArg (toString world.storePath)} ${lib.escapeShellArg "${savesDir}/${world.folderName}"}
          chmod -R u+w ${lib.escapeShellArg "${savesDir}/${world.folderName}"}
          noteEcho "Installed world: ${world.folderName}"
        fi
      '')
      worlds;
  in
    if worlds == {}
    then ""
    else ''
      run mkdir -p ${lib.escapeShellArg savesDir}
      ${concatStringsSep "\n" worldScripts}
    '';

  # Generate shell script to sync declared servers into an instance's servers.dat.
  # Emitted even for an empty list so removing the last server still cleans up;
  # the script's own guard skips instances that never used the feature.
  mkServersSetupScript = instanceName: servers:
    scripts.mkServersSetupScript {
      inherit prismDir instanceName;
      serversJsonFile = pkgs.writeText "prism-servers-${instanceName}.json" (builtins.toJSON servers);
    };

  # Build a filtered modpack source when excludeMods is set
  filterModpackSource = source: excludeMods:
    if excludeMods == []
    then source
    else
      pkgs.runCommand "filtered-modpack" {
        nativeBuildInputs = [pkgs.packwiz];
        src = source;
      } ''
        cp -r $src $out
        chmod -R u+w $out
        for mod in ${lib.escapeShellArgs excludeMods}; do
          rm -f "$out/mods/$mod.pw.toml"
        done
        cd $out
        packwiz refresh
      '';

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
    filteredSource = filterModpackSource modpack.source modpack.excludeMods;
    # Parse the original source: excludeMods only strips files under mods/, so
    # pack.toml is identical and stays readable as an eval-time path.
    parsed = parsePackToml modpack.source;
    iconResolved = resolveIcon modpack.icon;
  in {
    name = validName;
    source = filteredSource;
    inherit (modpack) group javaArgs javaPackage minMemory maxMemory excludeMods enableGameMode enableMangoHud useDiscreteGpu servers;
    worlds = lib.mapAttrs resolveWorld modpack.worlds;
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

  # Prism's compiled-in heap defaults, in MiB
  prismDefaultMinMemory = 512;
  prismDefaultMaxMemory = 4096;

  # Generate instance.cfg content
  mkInstanceCfg = name: modpack: let
    # A single OverridePerformance gate unlocks all three performance keys.
    needsPerformanceOverride =
      modpack.enableGameMode || modpack.enableMangoHud || modpack.useDiscreteGpu;
    # Under OverrideMemory an omitted key falls back to Prism's default, not the
    # launcher-wide value - so write both.
    needsMemoryOverride = modpack.minMemory != null || modpack.maxMemory != null;
    minMemory =
      if modpack.minMemory != null
      then modpack.minMemory
      else prismDefaultMinMemory;
    maxMemory =
      if modpack.maxMemory != null
      then modpack.maxMemory
      else prismDefaultMaxMemory;
  in ''
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
    ${optionalString (modpack.javaPackage != null) ''
      AutomaticJava=false
      IgnoreJavaCompatibility=true
      OverrideJavaLocation=true
      JavaPath=${modpack.javaPackage}/bin/java
    ''}
    ${optionalString needsMemoryOverride ''
      OverrideMemory=true
      MinMemAlloc=${toString minMemory}
      MaxMemAlloc=${toString maxMemory}
    ''}
    ${optionalString needsPerformanceOverride "OverridePerformance=true"}
    ${optionalString modpack.enableGameMode "EnableFeralGamemode=true"}
    ${optionalString modpack.enableMangoHud "EnableMangoHud=true"}
    ${optionalString modpack.useDiscreteGpu "UseDiscreteGpu=true"}
  '';

  # Modpack submodule options
  modpackOpts = {
    options = {
      source = mkOption {
        type = types.path;
        description = "Path to packwiz modpack directory containing pack.toml";
      };

      excludeMods = mkOption {
        type = types.listOf types.str;
        default = [];
        example = ["tweakeroo" "tweakermore"];
        description = "List of mod names to exclude (matches mods/<name>.pw.toml)";
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

      javaPackage = mkOption {
        type = types.nullOr types.package;
        default = null;
        example = literalExpression "pkgs.jdk25";
        description = "Java package for this instance (overrides Prism's auto-detect)";
      };

      minMemory = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
        example = 2048;
        description = ''
          Minimum heap size in MiB. Setting either memory option overrides the
          launcher-wide setting for this instance; the one left unset takes
          Prism's default (${toString prismDefaultMinMemory} min,
          ${toString prismDefaultMaxMemory} max) rather than your global value.
        '';
      };

      maxMemory = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
        example = 8192;
        description = "Maximum heap size in MiB (see minMemory)";
      };

      enableGameMode = mkOption {
        type = types.bool;
        default = false;
        description = "Enable Feral GameMode for CPU/IO optimizations while playing";
      };

      enableMangoHud = mkOption {
        type = types.bool;
        default = false;
        description = "Enable MangoHud FPS/GPU/CPU overlay";
      };

      useDiscreteGpu = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Render on the discrete GPU (Prism's "Use discrete GPU"). Only for
          hybrid offload hosts; drive from config.hostSpec.gpu.offload.
        '';
      };

      worlds = mkOption {
        type = types.attrsOf (types.submodule worldOpts);
        default = {};
        description = "World saves to install into this instance's saves directory";
        example = literalExpression ''
          {
            "pvp-practice" = {
              url = "https://example.com/pvp-map.zip";
              hash = "sha256-...";
              folderName = "PVP Practice Map";
            };
          }
        '';
      };

      servers = mkOption {
        type = types.listOf (types.submodule serverOpts);
        default = [];
        description = ''
          Multiplayer servers to ensure are present in this instance's server
          list. The module manages only the servers it adds: a declared server is
          created (or, if its address matches an existing entry, has its name
          synced and is promoted to a pinned entry), and removing one from config
          removes it from Minecraft on the next switch. Servers added in-game are
          left untouched. List order sets display order.
        '';
        example = literalExpression ''
          [
            {
              name = "Bow SMP";
              address = "play.bowchickawowwow.co.uk:25565";
            }
          ]
        '';
      };
    };
  };

  # Multiplayer server submodule options
  serverOpts = {
    options = {
      name = mkOption {
        type = types.str;
        example = "Bow SMP";
        description = "Display name in the multiplayer server list (supports § color codes)";
      };

      address = mkOption {
        type = types.str;
        example = "play.example.com:25565";
        description = "Server address (host, or host:port); matched verbatim against existing entries";
      };

      acceptTextures = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Server resource packs: true = auto-accept, false = decline, null = prompt (Minecraft default)";
      };
    };
  };

  # World save submodule options
  worldOpts = {
    options = {
      source = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to an extracted world save directory";
      };

      url = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "URL to a world save zip archive";
      };

      hash = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "SRI hash for the zip download (required with url)";
      };

      folderName = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Save folder name in .minecraft/saves/ (defaults to attribute name)";
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

  # Pre-resolve all modpacks (applies excludeMods filtering)
  resolvedModpacks = lib.mapAttrs resolveModpack cfg.modpacks;

  # Generate instance setup scripts
  instanceSetups = mapAttrsToList (name: resolved:
    scripts.mkInstanceSetup {
      inherit name prismDir;
      mmcPackJson = mkMmcPackJson resolved;
      instanceCfg = mkInstanceCfg name resolved;
      worldSetupScript = mkWorldSetupScript name resolved.worlds;
      serversSetupScript = mkServersSetupScript name resolved.servers;
    })
  resolvedModpacks;

  managedInstancesStr = concatStringsSep " " (builtins.attrNames cfg.modpacks);
in {
  # Extend upstream programs.prismlauncher with modpack options
  options.programs.prismlauncher = {
    onPrismRunning = mkOption {
      type = types.enum ["ignore" "skip" "close" "force-close"];
      default = "ignore";
      example = "close";
      description = ''
        What to do when instance files need writing while Prism Launcher is running.
        Prism rewrites instance.cfg wholesale from memory, so writes made under a
        live launcher are reverted the moment it saves any setting.

        - `"ignore"`: write anyway
        - `"skip"`: leave instances untouched, apply on the next activation
        - `"close"`: quit Prism first, unless a game is running (then skip)
        - `"force-close"`: quit Prism first even if a game is running
      '';
    };

    cleanupOrphans = mkOption {
      type = types.bool;
      default = true;
      description = "Remove instances that were managed by this module but are no longer in config";
    };

    modpacks = mkOption {
      type = types.attrsOf (types.submodule modpackOpts);
      default = {};
      description = "Packwiz modpack definitions (versions auto-detected from pack.toml)";
      example = literalExpression ''
        {
          "my-pack" = {
            source = ./modpacks/my-pack;
            icon = ./icons/my-pack.png;
            group = "Modded";
            maxMemory = 8192;
          };
        }
      '';
    };
  };

  config = mkIf (cfg.enable && hasModpacks) {
    assertions =
      mapAttrsToList (name: modpack: {
        assertion =
          modpack.minMemory
          == null
          || modpack.maxMemory == null
          || modpack.maxMemory >= modpack.minMemory;
        message = "programs.prismlauncher.modpacks.\"${name}\": maxMemory (${toString modpack.maxMemory}) must be at least minMemory (${toString modpack.minMemory})";
      })
      cfg.modpacks;

    # Add packwiz tool (prismlauncher package handled by upstream module)
    home.packages = [pkgs.packwiz];

    home.file = mkMerge [
      # Packwiz bootstrap jar
      {"${packwizDir}/packwiz-installer-bootstrap.jar".source = packwizBootstrap;}

      # Packwiz modpack files (uses filtered source when excludeMods is set).
      # Pack dirs are read-only: `packwiz refresh`/`add` can't write here.
      # Edit the pack source and rebuild instead.
      (mkMerge (mapAttrsToList (name: resolved: {
          "${packwizDir}/${name}" = {
            inherit (resolved) source;
          };
        })
        resolvedModpacks))

      # Custom icons
      (mkMerge (mapAttrsToList (key: path: {
          "${prismDir}/icons/${key}${
            lib.optionalString (builtins.match ".*\\.[^.]+$" (toString path) != null) (let
              filename = baseNameOf (toString path);
              ext = lib.last (lib.splitString "." filename);
            in ".${ext}")
          }".source =
            path;
        })
        customIcons))
    ];

    # Create writable instance files and manage groups
    home.activation.setupPrismInstances = lib.hm.dag.entryAfter ["writeBoundary"] ''
      ${scripts.mkRunningGuard {mode = cfg.onPrismRunning;}}
      if [ "''${prismSkip:-}" != "1" ]; then
        ${optionalString cfg.cleanupOrphans (scripts.mkCleanupScript {inherit prismDir managedInstancesStr;})}
        ${concatStringsSep "\n" instanceSetups}
        ${scripts.mkUpdateGroupsScript {inherit prismDir instGroupsJson;}}
      fi
    '';
  };
}
