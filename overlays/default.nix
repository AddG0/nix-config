#
# This file defines overlays/custom modifications to upstream packages
#
{inputs, ...}: let
  # Import the shared package definitions
  # This keeps packages lazy - they're only evaluated when accessed
  mkCustomPackages = import ../pkgs/packages.nix;

  # Create additions overlay that automatically merges with existing nixpkgs namespaces
  additions = final: prev: let
    # Get our custom packages - evaluated lazily on demand
    customPkgs = mkCustomPackages prev;

    # Helper to smartly merge a package/namespace
    mergePackage = name: value:
      if builtins.hasAttr name prev
      then
        # If it exists in nixpkgs, we need to merge
        if builtins.isAttrs value && builtins.isAttrs prev.${name}
        then
          # Both are attrsets, merge them
          prev.${name} // value
        else if builtins.isFunction prev.${name} && builtins.isAttrs value
        then
          # Special case: nixpkgs has a function (like themes), we have an attrset
          # Make it work as both using __functor
          value // {__functor = self: prev.${name};}
        else
          # Otherwise just override
          value
      else
        # Doesn't exist in nixpkgs, just add it
        value;
  in
    # Map over all our custom packages and merge them intelligently
    builtins.mapAttrs mergePackage customPkgs;

  linuxModifications = _final: prev:
    if prev.stdenv.isLinux
    then {
      # Linux-specific packages here
    }
    else {};

  darwinModifications = _final: prev:
    if prev.stdenv.isDarwin
    then {
      # Darwin-specific packages here
    }
    else {};

  modifications = _final: prev: {
    # example = prev.example.overrideAttrs (oldAttrs: let ... in {
    # ...
    # });
    #    flameshot = prev.flameshot.overrideAttrs {
    #      cmakeFlags = [
    #        (prev.lib.cmakeBool "USE_WAYLAND_GRIM" true)
    #        (prev.lib.cmakeBool "USE_WAYLAND_CLIPBOARD" true)
    #      ];
    #    };

    # btop with GPU support for NVIDIA and AMD
    btop = prev.symlinkJoin {
      name = "btop-${prev.btop.version}";
      paths = [prev.btop];
      buildInputs = [prev.makeWrapper];
      postBuild = prev.lib.optionalString prev.stdenv.isLinux ''
        # Wrap btop with NVIDIA and AMD libraries for GPU monitoring
        wrapProgram $out/bin/btop \
          --prefix LD_LIBRARY_PATH : "${prev.lib.makeLibraryPath ([
            prev.linuxPackages.nvidia_x11
          ]
          ++ prev.lib.optionals (prev ? rocmPackages) [
            prev.rocmPackages.rocm-smi
          ])}"
      '';
    };

    # Fix SDDM Wayland session bug where command is passed as single quoted string
    # Without this sddm will not work properly in wayland sessions.
    kdePackages = prev.kdePackages.overrideScope (_kfinal: kprev: {
      sddm = kprev.sddm.override {
        unwrapped = kprev.sddm.unwrapped.overrideAttrs (oldAttrs: {
          postInstall =
            (oldAttrs.postInstall or "")
            + ''
              # Fix wayland-session script to handle SDDM passing command as single string
              substituteInPlace $out/share/sddm/scripts/wayland-session \
                --replace-warn 'exec $@' \
                  $'# Handle SDDM bug where command is passed as single quoted string\nif [ $# -eq 1 ]; then\n  # Use sh -c to properly parse single argument (SDDM Wayland bug workaround)\n  exec sh -c "$1"\nelse\n  exec "$@"\nfi'
            '';
        });
      };
    });

    ghostty = inputs.ghostty.packages.${prev.stdenv.hostPlatform.system}.default;
    firefox-addons = import inputs.firefox-addons {
      inherit (prev) fetchurl lib stdenv;
    };

    # Cursor with fixed StartupWMClass
    code-cursor = prev.code-cursor.overrideAttrs (oldAttrs: {
      postFixup =
        (oldAttrs.postFixup or "")
        + ''
          # Fix StartupWMClass to match actual window class in both desktop files
          if [ -f "$out/share/applications/cursor.desktop" ]; then
            sed -i 's/StartupWMClass=cursor/StartupWMClass=Cursor/' $out/share/applications/cursor.desktop
          fi
          if [ -f "$out/share/applications/cursor-url-handler.desktop" ]; then
            sed -i 's/StartupWMClass=cursor/StartupWMClass=Cursor/' $out/share/applications/cursor-url-handler.desktop
          fi
        '';
    });

    # LosslessCut with desktop entry
    losslesscut = prev.losslesscut-bin.overrideAttrs (oldAttrs: {
      postInstall =
        (oldAttrs.postInstall or "")
        + ''
                  mkdir -p $out/share/applications
                  cat > $out/share/applications/losslesscut.desktop << EOF
          [Desktop Entry]
          Name=LosslessCut
          Comment=Swiss army knife of lossless video/audio editing
          Exec=$out/bin/losslesscut %F
          Icon=losslesscut
          Type=Application
          Categories=AudioVideo;Video;AudioVideoEditing;
          MimeType=video/mp4;video/x-matroska;video/webm;video/quicktime;
          StartupWMClass=LosslessCut
          EOF
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
                    cp "${prev.discord}/share/icons/hicolor/''${size}x''${size}/apps/discord.png" "$icon_dir/discord.png"
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

    # Lens with custom icon
    # lens = prev.lens.overrideAttrs (oldAttrs: {
    #   postInstall =
    #     (oldAttrs.postInstall or "")
    #     + ''
    #       # Replace the icon with the custom one
    #       ${prev.imagemagick}/bin/convert ${prev.fetchurl {
    #         url = "https://k8slens.dev/apple-icon1.png?85effbc6ebf0dbe5";
    #         sha256 = "0frva3inbw35ym19wjsgblbas4c47dpjq9qmsv8l9ijndiq3d3db";
    #       }} -resize 512x512 $out/share/icons/hicolor/512x512/apps/lens-desktop.png
    #     '';
    # });
  };

  stable-packages = final: _prev: {
    stable = import inputs.nixpkgs-stable {
      inherit (final.stdenv.hostPlatform) system;
      config.allowUnfree = true;
      #      overlays = [
      #     ];
    };
  };

  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final.stdenv.hostPlatform) system;
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
                pterodactyl-wings = importedNur.repos.xddxdd.pterodactyl-wings.overrideAttrs (_old: {
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
