# The builder probe over a fixture machines list; cases in ./probe.bats.
{
  harness,
  pkgs,
  lib,
  ...
}: let
  inherit (import ../../../_nix-builders.nix) builders;

  inherit
    (lib.evalModules {
      specialArgs = {
        inherit pkgs;
        inputs.nix-secrets = "/nonexistent";
      };
      modules = [
        ../client.nix
        # Only the NixOS options the client module reads or writes.
        {
          options = {
            hostSpec = lib.mkOption {type = lib.types.anything;};
            sops = lib.mkOption {type = lib.types.anything;};
            programs.ssh = lib.mkOption {type = lib.types.anything;};
            systemd = lib.mkOption {type = lib.types.anything;};
            nix = {
              distributedBuilds = lib.mkOption {type = lib.types.anything;};
              buildMachines = lib.mkOption {type = lib.types.anything;};
              settings = lib.mkOption {type = lib.types.anything;};
            };
          };
        }
        {
          # Every builder at a loopback address with nothing listening, so each probe is refused at once.
          hostSpec = {
            disableSops = false;
            hostName = "t";
            networking = {
              ports.tcp.ssh = 22;
              hostsAddr = lib.mapAttrs (_: _: {ipv4 = "127.0.0.1";}) builders;
            };
          };
        }
      ];
    })
    config
    ;
in
  harness.bats "nix-builder-probe" [./probe.bats] {
    probe = config.systemd.services.nix-builder-probe.serviceConfig.ExecStart;
    machines = lib.concatMapStrings (name: "ssh-ng://builder@${name} x86_64-linux - 20 100 - - -\n") (lib.attrNames builders);
  }
