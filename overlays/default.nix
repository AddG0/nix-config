#
# This file defines overlays/custom modifications to upstream packages
#
{inputs, ...}: let
  # Import the shared package definitions
  # This keeps packages lazy - they're only evaluated when accessed
  mkCustomPackages = import ../pkgs/packages.nix;

  # Create additions overlay that automatically merges with existing nixpkgs namespaces
  additions = _final: prev: let
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
          value // {__functor = _self: prev.${name};}
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
      claude-desktop = inputs.claude-desktop.packages.${prev.stdenv.hostPlatform.system}.claude-desktop-with-fhs;
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

    # VSCode extension patches
    vscode-marketplace-release =
      prev.vscode-marketplace-release
      // {
        # Fix debug extensions writing .noConfigDebugAdapterEndpoints to read-only extension dir
        # Redirect to XDG_STATE_HOME instead. Uses regex to survive minified variable name changes.
        vscjava =
          prev.vscode-marketplace-release.vscjava
          // {
            vscode-java-debug = prev.vscode-marketplace-release.vscjava.vscode-java-debug.overrideAttrs (old: {
              postInstall =
                (old.postInstall or "")
                + ''
                  sed -i -E 's/([a-zA-Z0-9]+)\.join\([a-zA-Z0-9]+,"\.noConfigDebugAdapterEndpoints"\)/\1.join(process.env.XDG_STATE_HOME||(process.env.HOME+"\/.local\/state"),"vscode-java-debug")/g' \
                    $out/share/vscode/extensions/vscjava.vscode-java-debug/dist/extension.js
                '';
            });
          };
      }
      // {
        github =
          prev.vscode-marketplace-release.github
          // {
            # Fix Copilot Chat copying read-only files to globalStorage
            # Node.js copyFile preserves permissions from nix store (read-only).
            # Patch to chmod files writable after copying.
            # Uses regex to match pattern regardless of minified variable names.
            copilot-chat = prev.vscode-marketplace-release.github.copilot-chat.overrideAttrs (old: {
              postInstall =
                (old.postInstall or "")
                + ''
                  sed -i -E 's/await ([a-zA-Z0-9]+)\.promises\.copyFile\(xr\(__dirname,([a-zA-Z0-9]+)\),xr\(([a-zA-Z0-9]+),\2\)\)/await \1.promises.copyFile(xr(__dirname,\2),xr(\3,\2)),await \1.promises.chmod(xr(\3,\2),438)/g' \
                    $out/share/vscode/extensions/github.copilot-chat/dist/extension.js
                '';
            });
          };
      }
      // prev.lib.optionalAttrs prev.stdenv.isLinux {
        # https://github.com/microsoft/vscode-gradle/issues/1589
        # Patch VSCode Java extension to use Nix-provided JDK instead of bundled dynamically-linked JRE
        redhat =
          prev.vscode-marketplace-release.redhat
          // {
            java = prev.vscode-marketplace-release.redhat.java.overrideAttrs (old: {
              postInstall =
                (old.postInstall or "")
                + ''
                  rm -rf $out/share/vscode/extensions/redhat.java/jre
                  mkdir -p $out/share/vscode/extensions/redhat.java/jre
                  ln -s ${prev.jdk21}/lib/openjdk $out/share/vscode/extensions/redhat.java/jre/21.0.9-linux-x86_64
                '';
            });
          };
      };

    vscode-marketplace =
      prev.vscode-marketplace
      // {
        # Fix debug extensions writing .noConfigDebugAdapterEndpoints to read-only extension dir
        # Redirect to XDG_STATE_HOME instead. Uses regex to survive minified variable name changes.
        ms-python =
          prev.vscode-marketplace.ms-python
          // {
            debugpy = prev.vscode-marketplace.ms-python.debugpy.overrideAttrs (old: {
              postInstall =
                (old.postInstall or "")
                + ''
                  sed -i -E 's/([a-zA-Z0-9]+)\.join\([a-zA-Z0-9]+,"\.noConfigDebugAdapterEndpoints"\)/\1.join(process.env.XDG_STATE_HOME||(process.env.HOME+"\/.local\/state"),"vscode-debugpy")/g' \
                    $out/share/vscode/extensions/ms-python.debugpy/dist/extension.js
                '';
            });
          };
      };

    # Fix gcloud interactive shell on NixOS (hardcoded /bin/bash)
    google-cloud-sdk = prev.google-cloud-sdk.overrideAttrs (old: {
      postInstall =
        (old.postInstall or "")
        + ''
          substituteInPlace $out/google-cloud-sdk/lib/googlecloudsdk/command_lib/interactive/coshell.py \
            --replace-fail "SHELL_PATH = '/bin/bash'" "SHELL_PATH = '${prev.bash}/bin/bash'"
          substituteInPlace $out/google-cloud-sdk/lib/googlecloudsdk/core/execution_utils.py \
            --replace-fail "shells = ['/bin/bash', '/bin/sh']" "shells = ['${prev.bash}/bin/bash', '/bin/sh']"
        '';
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
    discord-legcord = prev.stdenv.mkDerivation {
      pname = "discord-legcord";
      inherit (prev.legcord) version;

      dontUnpack = true;

      nativeBuildInputs = [];

      installPhase = ''
        mkdir -p $out/bin $out/share/applications $out/share/icons/hicolor

        # Link legcord binary and create discord alias
        ln -s "${prev.legcord}/bin/legcord" "$out/bin/legcord"
        ln -s "$out/bin/legcord" "$out/bin/discord"

        # Copy Discord icons as legcord.png (to match Icon=legcord)
        for size in 16 32 48 64 128 256 512 1024; do
          src_icon="${prev.discord}/share/icons/hicolor/''${size}x''${size}/apps/discord.png"
          if [ -f "$src_icon" ]; then
            mkdir -p "$out/share/icons/hicolor/''${size}x''${size}/apps"
            cp "$src_icon" "$out/share/icons/hicolor/''${size}x''${size}/apps/legcord.png"
          fi
        done

        # Create desktop file named legcord.desktop (matches desktopFile: legcord)
        cat > "$out/share/applications/legcord.desktop" << EOF
        [Desktop Entry]
        Name=Discord
        Comment=All-in-one voice and text chat for gamers
        Exec=legcord
        Icon=legcord
        Type=Application
        Categories=Network;InstantMessaging;
        StartupWMClass=legcord
        EOF
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
      # Remove replaceStdenv because main nixpkgs sets it to null by default,
      # but stable's stdenv/default.nix uses `config ? replaceStdenv` (not `!= null`)
      # which incorrectly triggers custom stdenv and tries to call null as a function.
      config = removeAttrs final.config ["replaceStdenv"];
    };
  };

  unstable-packages = final: _prev: {
    unstable = import inputs.nixpkgs-unstable {
      inherit (final.stdenv.hostPlatform) system;
      inherit (final) config;
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

  vscode-marketplace = inputs.nix-vscode-extensions.overlays.default;

  bakkesmod = inputs.bakkesmod-nix.overlays.default;

  ai-toolkit = inputs.ai-toolkit.overlays.default;
in {
  # Use composeManyExtensions so each overlay sees the result of previous overlays in `prev`
  default = inputs.nixpkgs.lib.composeManyExtensions [
    vscode-marketplace
    stable-packages
    unstable-packages
    nur
    bakkesmod
    ai-toolkit
    additions
    modifications
    linuxModifications
    darwinModifications
  ];
}
