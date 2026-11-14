# Desktop Steam inherits Gaming Mode's -steamdeck; greyed-out Friends/Chat = oobe_stage_2_completed unset.
{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  library = config.gaming.steam.sharedLibrary;
  group = "steam-library";

  # Game-folder files in the shared library get one writer, so its records survive whichever users sign in.
  libraryFiles = import ./_library-files.nix {inherit lib;} (lib.attrValues (config.home-manager.users or {}));
  steamConfigPatcher = pkgs.python3Packages.toPythonModule (
    pkgs.python3Packages.callPackage "${inputs.steam-config-nix}/pkgs/steam-config-patcher/package.nix" {}
  );
  placeLibraryFiles = pkgs.writers.writePython3 "library-files" {
    libraries = [steamConfigPatcher];
    flakeIgnore = ["E501"];
  } (builtins.readFile ./library-files.py);
  libraryFilesJson = pkgs.writeText "library-files.json" (builtins.toJSON libraryFiles.ops);
  libraryFilesState = "steam-library-files";
  # Wine refuses another uid's prefix, so Steam's sandbox swaps in the launching user's own compatdata.
  ownCompatdata = "$HOME/.local/share/steam-library-compatdata";

  # Steam rewrites libraryfolders.vdf itself, so the library is merged in at each launch instead of linked.
  registerLibrary =
    pkgs.writers.writePython3 "steam-library-register" {
      libraries = [pkgs.python3Packages.vdf];
      flakeIgnore = ["E501"];
    } ''
      import hashlib
      import os
      import sys

      import vdf

      library = sys.argv[1]
      steam = os.path.expanduser("~/.local/share/Steam")
      # The same id in every user's entry, so Steam sees one library rather than one per user.
      contentid = str(int(hashlib.sha256(library.encode()).hexdigest()[:15], 16))
      # Unlabelled, Steam names a library after its filesystem, the same as the home library's when they share one.
      label = "Shared"


      def write(path, data):
          with open(path + ".tmp", "w") as f:
              vdf.dump(data, f, pretty=True)
          os.replace(path + ".tmp", path)


      # Steam reads config/ once it has run; steamapps/ is seeded before the first run so a new user starts with both.
      for rel in ("config", "steamapps"):
          path = f"{steam}/{rel}/libraryfolders.vdf"
          if os.path.exists(path):
              with open(path) as f:
                  data = vdf.load(f)
          elif rel == "steamapps":
              os.makedirs(os.path.dirname(path), exist_ok=True)
              data = {"libraryfolders": {"0": {"path": steam, "label": "", "apps": {}}}}
          else:
              continue
          folders = data["libraryfolders"]
          entry = next((v for v in folders.values() if isinstance(v, dict) and v.get("path") == library), None)
          if entry is None:
              key = str(max((int(k) for k in folders if k.isdigit()), default=-1) + 1)
              folders[key] = {"path": library, "label": label, "contentid": contentid, "apps": {}}
              print(f"steam-library: registered {library} in {path}")
          elif not entry.get("label"):
              entry["label"] = label
              print(f"steam-library: labelled {library} in {path}")
          else:
              continue
          write(path, data)

      # Steam also keeps the label in the library itself; a rename in Steam's Storage page is left alone.
      marker = f"{library}/libraryfolder.vdf"
      if os.path.exists(marker):
          with open(marker) as f:
              data = vdf.load(f)
          if not data["libraryfolder"].get("label"):
              data["libraryfolder"]["label"] = label
              write(marker, data)
    '';
in {
  options.gaming.steam = {
    sharedLibrary = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/srv/steam-library";
      description = "A Steam library every hostSpec user installs into, registered in each user's Steam at launch.";
    };
    reshade = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["automobilista-2"];
      description = "steam/games.nix games whose opt-in ReShade setup this host applies; their presets may need adding to the Nix store by hand.";
    };
  };

  config = lib.mkMerge [
    {
      programs.steam = {
        enable = true;
        protontricks.enable = true;

        package = pkgs.steam.override ({
            extraPkgs = pkgs: (builtins.attrValues {
              inherit
                (pkgs.stdenv.cc.cc)
                lib
                ;

              inherit
                (pkgs)
                libxcursor
                libxi
                libxinerama
                libxscrnsaver
                libpng
                libpulseaudio
                libvorbis
                libkrb5
                keyutils
                gperftools
                libGLU # Level Devil's native build
                ;
            });

            # Everything that connects to the debugger is retargeted to match in
            # overlays/common/gaming/css-loader-retarget-steam-devtools-port.nix.
            extraArgs = "-devtools-port 21379";

            extraPreBwrapCmds =
              lib.optionalString config.networking.networkmanager.enable ''
                # A first run downloads Steam's client and quits if offline, which a login at boot often is.
                if [ ! -e "$HOME/.local/share/Steam/ubuntu12_32/steamui.so" ]; then
                  ${pkgs.networkmanager}/bin/nm-online -q -t 60 \
                    || echo "steam: still offline after 60s; its first-run client download will fail" >&2
                fi
              ''
              + lib.optionalString (library != null) ''
                mkdir -p "${ownCompatdata}"
                ${registerLibrary} ${lib.escapeShellArg library} \
                  || echo "steam-library: could not register ${library} in $HOME's Steam; add it under Settings > Storage" >&2
              '';
          }
          // lib.optionalAttrs (library != null) {
            extraBwrapArgs = [''--bind "${ownCompatdata}" ${lib.escapeShellArg "${library}/steamapps/compatdata"}''];
          });

        # No extraCompatPackages: it would bake a collectable store path into every
        # Proton prefix. The gaming home module installs the tools instead.
      };
    }

    (lib.mkIf (library != null) {
      users.groups.${group}.members = config.hostSpec.users;

      # The default ACL gives group write past Steam's umask; setgid keeps new files in the group.
      systemd.tmpfiles.rules = [
        "d ${library} 2770 root ${group} -"
        "a+ ${library} - - - - default:group::rwx,default:mask::rwx"
        "d ${library}/steamapps 2770 root ${group} -"
        "a+ ${library}/steamapps - - - - default:group::rwx,default:mask::rwx"
        # Only the empty mount point; outside Steam's sandbox nobody's prefixes show here.
        "d ${library}/steamapps/compatdata 0755 root root -"
      ];

      assertions = [
        {
          assertion = libraryFiles.conflicts == [];
          message = "gaming.steam: users declare different contents for ${lib.concatStringsSep ", " libraryFiles.conflicts} in the shared library ${library}.";
        }
      ];

      users.users.steam-library = {
        isSystemUser = true;
        inherit group;
      };

      # Runs even with nothing declared, so files that left the config are reverted.
      systemd.services.steam-library-files = {
        description = "Place declared game files in the shared Steam library";
        wantedBy = ["multi-user.target"];
        after = ["systemd-tmpfiles-setup.service"];
        # Steam rewrites appmanifest files throughout a download; a tripped start limit would fail the path unit.
        startLimitIntervalSec = 0;
        environment.XDG_DATA_HOME = "/var/lib/${libraryFilesState}";
        serviceConfig = {
          Type = "oneshot";
          User = "steam-library";
          Group = group;
          UMask = "0002";
          StateDirectory = libraryFilesState;
          ExecStart = "${placeLibraryFiles} ${lib.escapeShellArg library} ${libraryFilesJson}";
        };
      };

      # Steam writes appmanifest_<id>.acf into steamapps on install and update.
      systemd.paths.steam-library-files = {
        description = "Place declared game files when a shared-library game is installed or updated";
        wantedBy = ["multi-user.target"];
        pathConfig.PathChanged = "${library}/steamapps";
      };
    })
  ];
}
