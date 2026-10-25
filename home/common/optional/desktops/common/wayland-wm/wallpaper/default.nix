# Wallpaper backend. Each subfolder of ~/Pictures/Wallpapers/ is dedicated:
#   default/         → `any` (catch-all)
#   <friendly-name>/ → that monitor's output (matches display.monitors.*.name)
#   <output-name>/   → fallback when the output isn't declared in
#                      config.display.monitors (e.g. laptops with transient
#                      external displays)
# OLED outputs are owned by wallpaper-guard.nix; their folder names are
# ignored here to avoid a definition conflict on services.wpaperd.settings.
#
# Folders are populated from two sources, declared-wins-on-conflict:
#   1. `wallpapers.images.<folder>."<filename>" = <source>` — declarative.
#      home.file materialises the symlinks; the wpaperd/picker resolution
#      knows about them immediately, on the same build.
#   2. Whatever's on disk under ~/Pictures/Wallpapers/. Picks up files you
#      drop in manually. Folder add/remove needs a rebuild (readDir at eval),
#      file add/remove inside an already-known folder does not.
#
# List your current outputs (run on the target host):
#   hyprctl monitors -j | jq -r '.[].name'
{
  config,
  lib,
  pkgs,
  customPkgs,
  ...
}: let
  homeDir = config.home.homeDirectory;
  baseDir = "${homeDir}/Pictures/Wallpapers";
  defaultFolderName = "default";
  defaultDir = "${baseDir}/${defaultFolderName}";
  thumbsCache = "${homeDir}/.cache/wallpaper-picker/thumbs";

  oledOutputs = map (m: m.output) (lib.filter (m: m.oled) config.display.monitors);

  monitorByFriendlyName = lib.listToAttrs (map (m: {
    inherit (m) name;
    value = m;
  }) (lib.filter (m: m.enabled && !m.oled) config.display.monitors));

  # Folders known declaratively via wallpapers.images — these are
  # authoritative on the first build (before home.file activation has
  # materialised them on disk).
  declaredFolders = lib.filter (
    n: n != defaultFolderName && config.wallpapers.images.${n} != {}
  ) (lib.attrNames config.wallpapers.images);

  # Folders found on disk under baseDir at eval time. Picks up anything
  # the user dropped in manually (or that home.file created on a prior
  # build) that isn't in `wallpapers.images`.
  diskFolders =
    if builtins.pathExists baseDir
    then
      lib.filter (
        n:
          n
          != defaultFolderName
          && (builtins.readDir baseDir).${n} == "directory"
      ) (builtins.attrNames (builtins.readDir baseDir))
    else [];

  # Effective per-monitor folders: union, deduped, declared-wins-on-conflict.
  existingFolders = lib.unique (declaredFolders ++ diskFolders);

  folderToOutput = folder:
    if lib.hasAttr folder monitorByFriendlyName
    then monitorByFriendlyName.${folder}.output
    else folder;

  pathForFolder = folder: "${baseDir}/${folder}";

  folderEntries = lib.concatMap (folder: let
    output = folderToOutput folder;
  in
    if lib.elem output oledOutputs
    then []
    else [
      {
        name = output;
        value = {
          path = pathForFolder folder;
          duration = "30m";
          sorting = "random";
        };
      }
    ])
  existingFolders;

  monitorSettings = lib.listToAttrs folderEntries;

  # Seed/refresh a symlink to the stylix image in the default folder.
  # Skip entirely when wallpapers.defaultSeed.enable is false — e.g. a
  # personal wallpaper-defaults module manages the default folder itself.
  # When enabled, the marker records which stylix image path we last
  # pointed at so we can detect a theme change and refresh, while still
  # letting user deletions persist:
  #   no marker            → first-time seed
  #   marker + file gone   → user deleted, leave it gone (even if stylix changed)
  #   marker + file + diff → stylix theme changed, re-point the symlink
  #   marker + file + same → no-op
  # Delete the marker to force an unconditional re-seed.
  seedScriptText = lib.optionalString config.wallpapers.defaultSeed.enable ''
    mkdir -p ${lib.escapeShellArg defaultDir}
    marker=${lib.escapeShellArg "${defaultDir}/.stylix-seeded"}
    file=${lib.escapeShellArg "${defaultDir}/_stylix-default.png"}
    current=${lib.escapeShellArg config.stylix.image}
    if [ ! -e "$marker" ]; then
      ln -sfn "$current" "$file"
      printf '%s\n' "$current" > "$marker"
    elif [ -e "$file" ] && [ "$(cat "$marker")" != "$current" ]; then
      ln -sfn "$current" "$file"
      printf '%s\n' "$current" > "$marker"
    fi
  '';

  # Resize each source image to a small JPG/PNG thumb the picker can load
  # quickly. Filename + extension preserved so the picker's click handler
  # can build the apply-path against the original folder unchanged.
  # Folders we generate thumbs for: every per-output folder plus default.
  thumbFolders = lib.unique (existingFolders ++ [defaultFolderName]);

  thumbScriptText =
    lib.concatMapStringsSep "\n" (folder: let
      src = "${baseDir}/${folder}";
      dst = "${thumbsCache}/${folder}";
    in ''
      if [ -d ${lib.escapeShellArg src} ]; then
        mkdir -p ${lib.escapeShellArg dst}
        for f in ${lib.escapeShellArg dst}/*; do
          [ -e "$f" ] || continue
          base=$(basename "$f")
          if [ ! -e ${lib.escapeShellArg src}/"$base" ]; then
            rm -f "$f"
          fi
        done
        for f in ${lib.escapeShellArg src}/*; do
          [ -f "$f" ] || continue
          base=$(basename "$f")
          out=${lib.escapeShellArg dst}/"$base"
          if [ ! -e "$out" ] || [ "$f" -nt "$out" ]; then
            magick "$f" -resize "x400>" -quality 80 "$out"
          fi
        done
      fi
    '')
    thumbFolders;

  prepPkg = pkgs.writeShellApplication {
    name = "wpaperd-prepare";
    runtimeInputs = with pkgs; [imagemagick coreutils];
    text = lib.concatStringsSep "\n" [seedScriptText thumbScriptText];
  };

  # Output -> { display, apply } per monitor. The picker reads thumbnails
  # from `display` (small pre-generated cache for fast loads) and passes
  # `apply` to wpaperctl on click (the real wallpaper).
  pickerFolderMap = builtins.listToAttrs (map (folder: {
      name = folderToOutput folder;
      value = {
        display = "${thumbsCache}/${folder}";
        apply = pathForFolder folder;
      };
    })
    existingFolders);

  # The picker's fallback when an output isn't in pickerFolderMap (e.g. a
  # laptop's transient HDMI display). Thumbs path for display, source for
  # apply.
  pickerDefaults = {
    display = "${thumbsCache}/${defaultFolderName}";
    apply = "${baseDir}/${defaultFolderName}";
  };

  c = config.lib.stylix.colors.withHashtag;

  pickerLauncher = pkgs.writeShellApplication {
    name = "wallpaper-picker-launch";
    runtimeInputs = with pkgs; [customPkgs.wallpaper-picker util-linux];
    text = ''
      export WP_FOLDERS=${lib.escapeShellArg (builtins.toJSON pickerFolderMap)}
      export WP_DEFAULTS=${lib.escapeShellArg (builtins.toJSON pickerDefaults)}
      export WP_OLED_OUTPUTS=${lib.escapeShellArg (builtins.toJSON oledOutputs)}
      export WP_BG=${lib.escapeShellArg c.base00}
      export WP_FG=${lib.escapeShellArg c.base05}
      export WP_BORDER=${lib.escapeShellArg c.base03}

      # Singleton via flock: spamming SUPER+W only ever opens one picker.
      # -n = non-blocking; flock exits with code 1 silently if another
      # instance is already holding the lock. The lock is released when
      # this process (and thus the exec'd picker) exits.
      LOCK="''${XDG_RUNTIME_DIR:-/tmp}/wallpaper-picker.lock"
      exec flock -n "$LOCK" wallpaper-picker "$@"
    '';
  };
in {
  imports = [./_hyprland.nix ./_niri.nix];

  options.wallpapers = {
    picker = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      internal = true;
      description = "Launcher for the wallpaper picker, for compositor binds.";
    };

    defaultSeed.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.wallpapers.images.default or {} == {};
      defaultText = lib.literalExpression ''wallpapers.images.default == {}'';
      description = ''
        Seed the default wallpaper folder with a symlink to the stylix
        image. Auto-disabled when `wallpapers.images.default` is non-empty
        (the declarative set replaces the seed).
      '';
    };

    images = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf (lib.types.either lib.types.path lib.types.package));
      default = {};
      example = lib.literalExpression ''
        {
          default = {
            "wallhaven-1kv693.jpg" = pkgs.fetchurl { url = "..."; hash = "..."; };
          };
          left = { "city.png" = ./city.png; };
        }
      '';
      description = ''
        Wallpapers to declaratively install. Keyed by folder name (which
        matches a monitor's friendly `name` or `default` for the catch-all).
        Each entry maps `"<filename>" = <source>` and becomes a symlink at
        ~/Pictures/Wallpapers/<folder>/<filename>.
      '';
    };
  };

  config = {
    services.wpaperd.enable = true;
    wallpapers.picker = pickerLauncher;

    # Stylix's hyprpaper target sets services.hyprpaper.enable = true at the
    # same priority; without mkForce this is a conflict, not an override.
    stylix.targets.hyprpaper.enable = lib.mkForce false;
    # Stylix's Hyprland target turns hyprpaper on too, which drew a second wallpaper under wpaperd.
    stylix.targets.hyprland.hyprpaper.enable = false;

    # ExecStartPre handles the default-folder seed and the picker thumbnails.
    # Doing this in HM activation would race wpaperd's restart on the
    # X-Restart-Triggers reload; here systemd guarantees ordering.
    systemd.user.services.wpaperd.Service.ExecStartPre = "${lib.getExe prepPkg}";

    # A manual reload also re-seeds the default and refreshes the thumbnails.
    desktop.session.reload.commands.wpaperd = "systemctl --user try-restart wpaperd.service";

    services.wpaperd.settings =
      monitorSettings
      // {
        any = {
          path = lib.mkForce defaultDir;
          duration = "30m";
          sorting = "random";
        };
      };

    # Materialise wallpapers.images.<folder>."<filename>" into the
    # corresponding ~/Pictures/Wallpapers/<folder>/<filename> symlink.
    home.file = lib.listToAttrs (
      lib.concatLists (
        lib.mapAttrsToList (
          folder: files:
            lib.mapAttrsToList (filename: source: {
              name = "Pictures/Wallpapers/${folder}/${filename}";
              value.source = source;
            })
            files
        )
        config.wallpapers.images
      )
    );
  };
}
