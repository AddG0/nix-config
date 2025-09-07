#
# This file defines overlays/custom modifications to upstream packages
#
{inputs, ...}: let
  # Adds my custom packages
  additions = final: prev:
    prev.lib.packagesFromDirectoryRecursive {
      callPackage = prev.lib.callPackageWith final;
      directory = ../pkgs/common;
    };

  linuxModifications = final: prev:
    if prev.stdenv.isLinux
    then {
      # Linux-specific packages here
    }
    else {};

  darwinModifications = final: prev:
    if prev.stdenv.isDarwin
    then {
      # Darwin-specific packages here
    }
    else {};

  modifications = final: prev: {

    # example = prev.example.overrideAttrs (oldAttrs: let ... in {
    # ...
    # });
    #    flameshot = prev.flameshot.overrideAttrs {
    #      cmakeFlags = [
    #        (prev.lib.cmakeBool "USE_WAYLAND_GRIM" true)
    #        (prev.lib.cmakeBool "USE_WAYLAND_CLIPBOARD" true)
    #      ];
    #    };

    ghostty = inputs.ghostty.packages.${prev.system}.default;
    firefox-addons = import inputs.firefox-addons {
      inherit (prev) fetchurl lib stdenv;
    };

    # Cursor with fixed StartupWMClass
    code-cursor = prev.cursor.overrideAttrs (oldAttrs: {
      postInstall =
        (oldAttrs.postInstall or "")
        + ''
          # Fix StartupWMClass to match actual window class
          sed -i 's/StartupWMClass=cursor/StartupWMClass=Cursor/' $out/share/applications/cursor.desktop
        '';
    });

    # Legcord with Discord branding
    discord-legcord = prev.symlinkJoin {
      name = "discord";
      paths = [prev.legcord];
      buildInputs = [prev.makeWrapper];
      postBuild = ''
                # Create a discord symlink to legcord binary
                if [ -f "$out/bin/legcord" ]; then
                  ln -sf "$out/bin/legcord" "$out/bin/discord"
                fi

                # Copy Discord icons over Legcord icons
                for size in 16 32 48 64 128 256 512 1024; do
                  icon_dir="$out/share/icons/hicolor/''${size}x''${size}/apps"
                  if [ -d "$icon_dir" ] && [ -f "${prev.discord}/share/icons/hicolor/''${size}x''${size}/apps/discord.png" ]; then
                    rm -f "$icon_dir/legcord.png"
                    cp "${prev.discord}/share/icons/hicolor/''${size}x''${size}/apps/discord.png" "$icon_dir/legcord.png"
                    # Also create discord.png symlink
                    ln -sf "$icon_dir/legcord.png" "$icon_dir/discord.png"
                  fi
                done

                # Create a new desktop file with Discord branding
                if [ -f "$out/share/applications/legcord.desktop" ]; then
                  rm -f "$out/share/applications/legcord.desktop"
                  cat > "$out/share/applications/discord.desktop" << EOF
        [Desktop Entry]
        Name=Discord
        Comment=All-in-one voice and text chat for gamers
        Exec=discord
        Icon=discord
        Type=Application
        Categories=Network;InstantMessaging;
        StartupWMClass=legcord
        EOF
                fi
      '';
    };
  };

  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      inherit (final) system;
      config.allowUnfree = true;
      #      overlays = [
      #     ];
    };
  };

  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final) system;
      config.allowUnfree = true;
      #      overlays = [
      #     ];
    };
  };

  nur = final: _prev: let
    importedNur = import inputs.nur {
      pkgs = final;
      nurpkgs = final;
    };
  in {
    nur =
      importedNur
      // {
        repos =
          importedNur.repos
          // {
            xddxdd =
              importedNur.repos.xddxdd
              // {
                pterodactyl-wings = importedNur.repos.xddxdd.pterodactyl-wings.overrideAttrs (old: {
                  doCheck = false;
                  # Fix hash mismatch for go modules
                  vendorHash = "sha256-tfv3jUoIQxFVshooe1f9K2v6vxXx8C02QdP/dcwz8vE=";
                });
              };
          };
      };
  };
in {
  default = final: prev:
    (additions final prev)
    // (modifications final prev)
    // (linuxModifications final prev)
    // (darwinModifications final prev)
    // (stable-packages final prev)
    // (unstable-packages final prev)
    // (nur final prev);
}
