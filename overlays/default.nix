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
      zen-browser = inputs.zen-browser.packages.${prev.stdenv.hostPlatform.system}.default;
    }
    else {};

  darwinModifications = _final: prev:
    if prev.stdenv.isDarwin
    then {
      # Darwin-specific packages here
    }
    else {};

  modifications = _final: prev: let
    # RVM ResNet50 model (107MB vs 15MB MobileNetV3) for better quality
    rvmResnet50Model = prev.fetchurl {
      url = "https://github.com/PeterL1n/RobustVideoMatting/releases/download/v1.0.0/rvm_resnet50_fp32.onnx";
      hash = "sha256-JdswD8tu4n+UGhtSyXhW6NHxPH81gX+BphL4mvDoqFw=";
    };
    # RMBG 1.4 FP32 full precision model (176MB vs 44MB quantized) for better quality
    rmbgFp32Model = prev.fetchurl {
      url = "https://huggingface.co/briaai/RMBG-1.4/resolve/main/onnx/model.onnx";
      hash = "sha256-jK/PdwsGdXxOrO0hsaiOV/0rZt4BuARfNfAVNbp0Lg8=";
    };
  in {
    # OBS Background Removal with CUDA support
    # Updated to 1.3.6 which has proper CUDA support on Linux
    # Patches RVM to support ResNet50 backbone for better quality
    obs-studio-plugins =
      prev.obs-studio-plugins
      // {
        obs-backgroundremoval = prev.obs-studio-plugins.obs-backgroundremoval.overrideAttrs (old: {
          version = "1.3.6";
          src = prev.fetchFromGitHub {
            owner = "royshil";
            repo = "obs-backgroundremoval";
            rev = "1.3.6";
            hash = "sha256-2BVcOH7wh1ibHZmaTMmRph/jYchHcCbq8mn9wo4LQOU=";
          };
          nativeBuildInputs = old.nativeBuildInputs ++ [prev.pkg-config];
          buildInputs =
            (map
              (dep:
                if dep.pname or "" == "onnxruntime"
                then prev.onnxruntime.override {cudaSupport = true;}
                else dep)
              old.buildInputs)
            ++ [prev.curl];
          cmakeFlags =
            (map
              (flag:
                if flag == "--preset linux-x86_64"
                then "--preset ubuntu-x86_64"
                else if flag == "-DDISABLE_ONNXRUNTIME_GPU=ON"
                then "-DDISABLE_ONNXRUNTIME_GPU=OFF"
                else flag)
              old.cmakeFlags)
            # Use pkg-config mode for finding dependencies (nixpkgs doesn't have cmake CONFIG files)
            ++ ["-DVCPKG_TARGET_TRIPLET=" "-DUSE_PKGCONFIG=ON"];
          # Patch source to support ResNet50 channel dimensions (16,32,64,128 vs MobileNetV3's 16,20,40,64)
          postPatch =
            (old.postPatch or "")
            + ''
              sed -i 's/(i == 1) ? 16 : (i == 2) ? 20 : (i == 3) ? 40 : 64/(i == 1) ? 16 : (i == 2) ? 32 : (i == 3) ? 64 : 128/g' src/models/ModelRVM.h
            '';
          # Replace models with higher quality versions
          installPhase =
            (old.installPhase or "")
            + ''
              # RVM: MobileNetV3 -> ResNet50 (107MB)
              rm -f $out/share/obs/obs-plugins/obs-backgroundremoval/models/rvm_mobilenetv3_fp32.onnx
              cp ${rvmResnet50Model} $out/share/obs/obs-plugins/obs-backgroundremoval/models/rvm_mobilenetv3_fp32.onnx
              # RMBG: Quantized -> FP32 (176MB)
              rm -f $out/share/obs/obs-plugins/obs-backgroundremoval/models/bria_rmbg_1_4_qint8.onnx
              cp ${rmbgFp32Model} $out/share/obs/obs-plugins/obs-backgroundremoval/models/bria_rmbg_1_4_qint8.onnx
            '';
        });
      };

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
in {
  # Use composeManyExtensions so each overlay sees the result of previous overlays in `prev`
  default = inputs.nixpkgs.lib.composeManyExtensions [
    vscode-marketplace
    stable-packages
    unstable-packages
    nur
    bakkesmod
    additions
    modifications
    linuxModifications
    darwinModifications
  ];
}
