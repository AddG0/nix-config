# Nix Remote Builder Configuration
#
# This module provides a centralized way to configure Nix remote builders.
# Hosts listed in allBuilders automatically become builders (create the builder user).
# Hosts can opt-in to using remote builders by setting `nix.remoteBuilder.enableClient = true`.
#
# The buildMachines list is automatically populated with all builders,
# excluding the current host (you can't build on yourself as a remote).
#
# The SSH private key is stored in sops and decrypted at runtime.
# SSH host keys are configured automatically to avoid manual known_hosts management.
{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
with lib; let
  # Define all builders here
  # Hosts listed here will automatically have the builder user created
  # hostKey is the SSH host public key (ed25519) for known_hosts configuration
  allBuilders = {
    loki = {
      system = "x86_64-linux";
      maxJobs = 20;
      speedFactor = 100;
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOoqypWaPrUfWk8uUATK/mVM1uMzDVJW5HlNuXRMBFAz";
    };
    odin = {
      system = "x86_64-linux";
      maxJobs = 20;
      speedFactor = 100;
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOZoUzRGlGQDkKc2PkWhANu2EQ75v8J7qGL09L+UXR/U";
    };
    thor = {
      system = "x86_64-linux";
      maxJobs = 20;
      speedFactor = 100;
      hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHeai+FZVjhCqBFYfvg0YF1xXkywmJSz9n4Q2CODJGsR";
    };
    # Add more builders here as needed:
    # ghost = {
    #   system = "aarch64-darwin";
    #   maxJobs = 8;
    #   speedFactor = 50;
    #   hostKey = "ssh-ed25519 AAAA...";
    # };
  };

  currentHost = config.hostSpec.hostName;
  isBuilder = hasAttr currentHost allBuilders;

  # Calculate total maxJobs from all remote builders (excluding current host)
  # Only count builders that match the current system's architecture
  totalRemoteJobs = let
    currentSystem = pkgs.stdenv.hostPlatform.system;

    # Filter to only builders matching current architecture and excluding current host
    remoteBuilders =
      filterAttrs
      (name: builder: name != currentHost && builder.system == currentSystem)
      allBuilders;

    sumJobs = builders: foldl' (acc: builder: acc + builder.maxJobs) 0 (attrValues builders);
  in
    sumJobs remoteBuilders;
in {
  options.nix.remoteBuilder = {
    enable = mkOption {
      type = types.bool;
      default = isBuilder;
      description = "Enable this host as a Nix remote builder (defaults to true if host is in allBuilders)";
    };

    enableClient = mkOption {
      type = types.bool;
      default = false;
      description = "Enable this host to use remote builders";
    };

    publicKey = mkOption {
      type = types.str;
      default = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPolgQKCN05Js3NXyBQGs4ii6tTmHYV2jRt79ZCdbMX5";
      description = "SSH public key for the builder user";
      example = "ssh-ed25519 AAAA...";
    };

    totalRemoteJobs = mkOption {
      type = types.int;
      default = totalRemoteJobs;
      readOnly = true;
      description = "Total maxJobs available from all remote builders on the same system architecture (calculated automatically)";
    };
  };

  # Remote builders require sops for SSH key decryption and client to be enabled
  config = mkIf (!config.hostSpec.disableSops && config.nix.remoteBuilder.enableClient) {
    # Decrypt the builder SSH key from sops
    sops.secrets.nix-builder-key = {
      sopsFile = "${inputs.nix-secrets}/global/nix-builder-key.enc";
      format = "binary";
      mode = "0400";
    };

    # Configure SSH known hosts for all builders to avoid manual host key verification
    # This ensures nix-daemon can connect without prompting for host key acceptance
    # Include both hostname and IP address to handle SSH resolution to either
    programs.ssh.knownHosts = mapAttrs (name: builderCfg: {
      hostNames = [name config.hostSpec.networking.hostsAddr.${name}.ipv4];
      publicKey = builderCfg.hostKey;
    }) (filterAttrs (_: cfg: cfg.hostKey or "" != "") allBuilders);

    # Configure buildMachines for all hosts (clients that want to use remote builders)
    nix.buildMachines = let
      currentHost = config.hostSpec.hostName;

      # Filter out current host and create buildMachine entries
      enabledBuilders = filterAttrs (name: _: name != currentHost) allBuilders;

      toBuildMachine = name: builderCfg: {
        hostName = name;
        inherit (builderCfg) system maxJobs speedFactor;
        protocol = "ssh-ng";
        sshUser = "builder";
        sshKey = config.sops.secrets.nix-builder-key.path;
      };
    in
      mapAttrsToList toBuildMachine enabledBuilders;

    # Only enable distributed builds if we have remote builders configured
    nix.distributedBuilds = length config.nix.buildMachines > 0;

    # Use substitutes on builders to avoid uploading everything
    nix.settings.builders-use-substitutes = true;
  };
}
