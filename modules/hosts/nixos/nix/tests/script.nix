# git-sync's ExecCondition against a fake `nix flake metadata` and fixture generations; cases in ./git-sync.bats.
{
  harness,
  pkgs,
  lib,
  ...
}: let
  # Prints $FLAKE_METADATA, standing in for `nix flake metadata --refresh --json`.
  fakeNix = pkgs.writeShellScriptBin "nix" ''
    printf '%s\n' "$FLAKE_METADATA"
  '';

  inherit
    (lib.evalModules {
      specialArgs.pkgs = pkgs // {nix = fakeNix;};
      modules = [
        (harness.module ../git-sync.nix)
        # Only the NixOS options git-sync reads or writes.
        {
          options = {
            assertions = lib.mkOption {
              type = lib.types.listOf lib.types.anything;
              default = [];
            };
            systemd = lib.mkOption {type = lib.types.anything;};
            networking.hostName = lib.mkOption {
              type = lib.types.str;
              default = "t";
            };
          };
        }
        {
          nix.git-sync = {
            enable = true;
            interval = "1h";
          };
        }
      ];
    })
    config
    ;
in
  harness.bats "git-sync" [./git-sync.bats] {
    checkNewer = config.systemd.services.nix-remote-rebuild.serviceConfig.ExecCondition;
  }
