{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.rcloneMounts;
  replaceSlashes = builtins.replaceStrings ["/"] ["."];
in {
  options.services.rcloneMounts = {
    enable = lib.mkEnableOption "rclone FUSE mounts (config managed by rclone, not nix)";

    package = lib.mkPackageOption pkgs "rclone" {};

    configPath = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.configHome}/rclone/mounts.conf";
      description = ''
        Path to rclone config file for mounts. Uses a separate file from
        the default rclone.conf to avoid conflicts with programs.rclone.
      '';
    };

    remotes = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            mounts = lib.mkOption {
              type = lib.types.attrsOf (
                lib.types.submodule {
                  options = {
                    logLevel = lib.mkOption {
                      type = lib.types.nullOr (
                        lib.types.enum ["ERROR" "NOTICE" "INFO" "DEBUG"]
                      );
                      default = null;
                      example = "INFO";
                      description = "Set the log-level. See: https://rclone.org/docs/#logging";
                    };

                    mountPoint = lib.mkOption {
                      type = lib.types.str;
                      description = "A local file path specifying the location of the mount point.";
                      example = "/home/alice/my-remote";
                    };

                    options = lib.mkOption {
                      type = with lib.types; attrsOf (nullOr (oneOf [bool int float str]));
                      default = {};
                      apply = lib.mergeAttrs {
                        vfs-cache-mode = "full";
                        cache-dir = "%C/rclone";
                      };
                      description = ''
                        An attribute set of option values passed to `rclone mount`.
                        Some caching options are set by default, namely `vfs-cache-mode = "full"`
                        and `cache-dir`. These can be overridden if desired.
                      '';
                    };
                  };
                }
              );
              default = {};
              description = ''
                An attribute set mapping remote file paths to their corresponding mount
                point configurations. Use "" for root of the remote.
              '';
              example = lib.literalExpression ''
                {
                  "" = {
                    mountPoint = "/home/alice/cloud/gdrive";
                    options.drive-export-formats = "docx,xlsx,pptx";
                  };
                  "Documents" = {
                    mountPoint = "/home/alice/docs";
                  };
                }
              '';
            };
          };
        }
      );
      default = {};
      description = ''
        Remotes to mount. The remote must already be configured in ~/.config/rclone/rclone.conf
        Run `rclone config` to set up remotes.
      '';
      example = lib.literalExpression ''
        {
          AddG.mounts."" = {
            mountPoint = "/home/user/cloud/AddG";
            options.drive-export-formats = "docx,xlsx,pptx";
          };
        }
      '';
    };
  };

  config = let
    mountServices = lib.listToAttrs (
      lib.concatMap
      (
        {
          name,
          value,
        }: let
          remote-name = name;
          remote = value;
        in
          lib.concatMap (
            {
              name,
              value,
            }: let
              mount-path = name;
              mount = value;
            in [
              (lib.nameValuePair "rclone-mount:${replaceSlashes mount-path}@${remote-name}" {
                Unit = {
                  Description = "Rclone FUSE daemon for ${remote-name}:${mount-path}";
                };

                Service = {
                  Type = "notify";
                  Environment =
                    [
                      # fusermount/fusermount3
                      "PATH=/run/wrappers/bin"
                    ]
                    ++ lib.optional (mount.logLevel != null) "RCLONE_LOG_LEVEL=${mount.logLevel}";

                  ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${mount.mountPoint}";
                  ExecStart = lib.concatStringsSep " " [
                    (lib.getExe cfg.package)
                    "mount"
                    "--config=${cfg.configPath}"
                    (lib.cli.toGNUCommandLineShell {} mount.options)
                    "${remote-name}:${mount-path}"
                    "${mount.mountPoint}"
                  ];
                  Restart = "on-failure";
                };

                Install.WantedBy = ["default.target"];
              })
            ]
          ) (lib.attrsToList remote.mounts)
      )
      (
        lib.pipe cfg.remotes [
          lib.attrsToList
          (lib.filter (rem: rem.value ? mounts))
        ]
      )
    );
  in
    lib.mkIf cfg.enable {
      home.packages = [cfg.package];
      systemd.user.services = mountServices;
    };
}
