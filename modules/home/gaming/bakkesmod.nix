# BakkesMod module for Home Manager
# Based on https://github.com/CrumblyLiquid/BakkesLinux
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.bakkesmod;

  # Plugin sync script - manages BakkesMod plugins
  bakkes-plugin-sync = pkgs.writeShellScriptBin "bakkes-plugin-sync" ''
    #!/usr/bin/env bash
    set -euo pipefail

    BAKKES_DATA="$1"

    if [ ! -d "$BAKKES_DATA" ]; then
        echo "BakkesMod data directory not found: $BAKKES_DATA"
        exit 1
    fi

    mkdir -p "$BAKKES_DATA/plugins"
    mkdir -p "$BAKKES_DATA/plugins/settings"
    mkdir -p "$BAKKES_DATA/data"

    # Build list of plugin names we want from Nix
    WANTED_PLUGINS=""
    ${concatMapStringsSep "\n" (plugin: ''
      if [ -d "${plugin}/share/bakkesmod" ]; then
          PLUGIN_NAME="${plugin.pname or "unknown"}"
          WANTED_PLUGINS="$WANTED_PLUGINS $PLUGIN_NAME"
      fi
    '') cfg.plugins}

    # Remove Nix-managed plugins that are no longer wanted
    for marker in "$BAKKES_DATA/plugins"/*.nix-managed; do
        if [ -f "$marker" ]; then
            PLUGIN_NAME=$(basename "$marker" .nix-managed)
            if ! echo "$WANTED_PLUGINS" | grep -qw "$PLUGIN_NAME"; then
                echo "Removing plugin: $PLUGIN_NAME"
                PLUGIN_NAME_LOWER=$(echo "$PLUGIN_NAME" | tr '[:upper:]' '[:lower:]')

                # Read list of files from marker and remove them
                while IFS= read -r file; do
                    rm -f "$BAKKES_DATA/$file" 2>/dev/null
                done < "$marker"

                # Remove the marker itself
                rm -f "$marker"

                # Remove from plugins.cfg
                if [ -f "$BAKKES_DATA/cfg/plugins.cfg" ]; then
                    # Remove the plugin load line
                    ${pkgs.gnused}/bin/sed -i "/^plugin load $PLUGIN_NAME_LOWER$/d" "$BAKKES_DATA/cfg/plugins.cfg"
                    echo "Disabled $PLUGIN_NAME in plugins.cfg"
                fi
            fi
        fi
    done

    # Copy/update Nix-managed plugins with all their files
    ${concatMapStringsSep "\n" (plugin: ''
      if [ -d "${plugin}/share/bakkesmod" ]; then
          PLUGIN_NAME="${plugin.pname or "unknown"}"
          PLUGIN_NAME_LOWER=$(echo "$PLUGIN_NAME" | tr '[:upper:]' '[:lower:]')
          MARKER_FILE="$BAKKES_DATA/plugins/$PLUGIN_NAME.nix-managed"

          echo "Installing/updating plugin: $PLUGIN_NAME"

          # Start fresh marker file
          > "$MARKER_FILE"

          # Copy all files from plugin package to BakkesMod data directory
          # This includes both plugins/ and data/ directories
          cd "${plugin}/share/bakkesmod"
          find . -type f | while read -r file; do
              # Remove leading ./
              REL_PATH="''${file#./}"

              # Create directory structure if needed
              DIR_PATH=$(dirname "$REL_PATH")
              if [ "$DIR_PATH" != "." ]; then
                  mkdir -p "$BAKKES_DATA/$DIR_PATH"
              fi

              # Copy file if newer or missing
              if [ ! -f "$BAKKES_DATA/$REL_PATH" ] || [ "$file" -nt "$BAKKES_DATA/$REL_PATH" ]; then
                  ${pkgs.coreutils}/bin/cp -f "$file" "$BAKKES_DATA/$REL_PATH"
              fi

              # Track in marker file (relative to BakkesMod root)
              echo "$REL_PATH" >> "$MARKER_FILE"
          done

          # Enable plugin in cfg/plugins.cfg
          mkdir -p "$BAKKES_DATA/cfg"
          touch "$BAKKES_DATA/cfg/plugins.cfg"

          # Check if plugin is already in config
          if ! grep -q "^plugin load $PLUGIN_NAME_LOWER$" "$BAKKES_DATA/cfg/plugins.cfg" 2>/dev/null; then
              echo "plugin load $PLUGIN_NAME_LOWER" >> "$BAKKES_DATA/cfg/plugins.cfg"
              echo "Enabled $PLUGIN_NAME in plugins.cfg"
          fi
      fi
    '') cfg.plugins}

    echo "Plugin sync complete"
  '';

  # Launcher script - runs BakkesMod when Rocket League starts
  bakkes-launcher = pkgs.writeShellScriptBin "bakkes-launcher" ''
    # BakkesMod launcher for NixOS
    # Add to Rocket League Steam launch options:
    #   bakkes-launcher %command%

    # Rocket League prefix and Proton paths
    RL_PREFIX="$HOME/.steam/steam/steamapps/compatdata/252950"

    # Detect Proton version from config_info (don't fail if it errors)
    PROTON=$(${pkgs.gnused}/bin/sed -n 3p "$RL_PREFIX/config_info" 2>/dev/null | ${pkgs.findutils}/bin/xargs -d '\n' dirname 2>/dev/null) || true

    # Ensure Windows 10 is set (BakkesMod requires it)
    if [ -d "$RL_PREFIX/pfx" ] && [ -n "$PROTON" ]; then
        WIN_VER=$(WINEPREFIX="$RL_PREFIX/pfx" "$PROTON/bin/wine64" reg query 'HKLM\Software\Microsoft\Windows NT\CurrentVersion' /v CurrentVersion 2>/dev/null | ${pkgs.gnugrep}/bin/grep "10.0" || echo "")
        if [ -z "$WIN_VER" ]; then
            WINEPREFIX="$RL_PREFIX/pfx" "$PROTON/bin/wine64" reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion' /v CurrentVersion /t REG_SZ /d "10.0" /f >/dev/null 2>&1
            WINEPREFIX="$RL_PREFIX/pfx" "$PROTON/bin/wine64" reg add 'HKLM\Software\Microsoft\Windows NT\CurrentVersion' /v CurrentBuild /t REG_SZ /d "19045" /f >/dev/null 2>&1
        fi
    fi

    # Background worker - launches BakkesMod when game starts
    (
        # Wait for Rocket League to start (the Windows exe, not the launcher)
        while ! ${pkgs.procps}/bin/pgrep -f "Z:.*RocketLeague.exe" 2> /dev/null; do
            ${pkgs.coreutils}/bin/sleep 1
        done

        # Let RL fully initialize before injecting
        ${pkgs.coreutils}/bin/sleep 5

        # Run BakkesMod directly from nix store - it's self-contained!
        WINEDEBUG=-all WINEFSYNC=1 WINEPREFIX="$RL_PREFIX/pfx" "$PROTON/bin/wine64" ${cfg.package}/bin/BakkesMod.exe 2>/dev/null &
        BAKKES_PID=$!

        # Wait for BakkesMod to create its data directory (max 30 seconds)
        BAKKES_DATA="$RL_PREFIX/pfx/drive_c/users/steamuser/AppData/Roaming/bakkesmod/bakkesmod"
        WAIT_COUNT=0
        while [ ! -d "$BAKKES_DATA" ] && [ $WAIT_COUNT -lt 30 ]; do
            ${pkgs.coreutils}/bin/sleep 1
            WAIT_COUNT=$((WAIT_COUNT + 1))
        done

        # Sync Nix-managed plugins while preserving manual ones
        if [ -d "$BAKKES_DATA" ]; then
            ${bakkes-plugin-sync}/bin/bakkes-plugin-sync "$BAKKES_DATA"
        fi
    ) &
    BAKKES_WORKER_PID=$!

    # Run the game in foreground
    "$@"
    GAME_EXIT_CODE=$?

    # Game exited - clean up BakkesMod
    kill $BAKKES_WORKER_PID 2>/dev/null
    ${pkgs.procps}/bin/pkill -f "BakkesMod.exe" 2>/dev/null

    exit $GAME_EXIT_CODE
  '';
in {
  options.programs.bakkesmod = {
    enable = mkEnableOption "BakkesMod for Rocket League";

    package = mkOption {
      type = types.package;
      default = pkgs.bakkesmod;
      description = "The BakkesMod package to use.";
    };

    plugins = mkOption {
      type = types.listOf types.package;
      default = [];
      example = literalExpression ''
        [
          pkgs.bakkesmod-plugins.ingamerank
        ]
      '';
      description = ''
        List of BakkesMod plugins to install via Nix.

        These plugins will be managed declaratively:
        - Added when in this list
        - Removed when removed from this list
        - Updated when the Nix package updates

        Manually installed plugins (those without .nix-managed markers)
        will be preserved and not touched by this module.

        Available plugins can be found in pkgs.bakkesmod-plugins.*

        Example: To add the IngameRank plugin, use:
        pkgs.bakkesmod-plugins.ingamerank
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      # To use: add 'bakkes-launcher %command%' to Rocket League Steam launch options
      bakkes-launcher
    ];
  };
}