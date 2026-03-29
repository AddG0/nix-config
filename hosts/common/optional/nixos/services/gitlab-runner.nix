# GitLab Runner using Docker executor with host Nix store mounted read-only.
#
# How it works:
#   - Each CI job runs in a fresh Docker container (default: ubuntu:latest)
#   - The host's /nix/store, DB, and daemon socket are bind-mounted into the container
#   - A preBuildScript bootstraps the Nix directory structure and installs nix + essential tools
#   - Jobs can then use `nix build`, `nix develop`, `nix print-dev-env`, etc.
#
# Security:
#   - The host Nix store is exposed read-only — only use with trusted repos
#   - The daemon socket allows triggering builds on the host, so limit to trusted CI jobs
#
# Image compatibility:
#   - The default image must have bash as /bin/sh (e.g. ubuntu, debian)
#   - Alpine won't work — its ash shell can't parse `nix print-dev-env` output
#   - Kaniko is auto-detected and skips the nix setup entirely
{
  # config,
  # inputs,
  lib,
  pkgs,
  ...
}: {
  # TODO: Wire up sops-nix for proper secret management
  # sops.secrets."gitlab-runner-token" = {
  #   sopsFile = "${inputs.nix-secrets}/users/${config.hostSpec.username}/gitlab/runner-token.env.enc";
  #   format = "binary";
  #   owner = "gitlab-runner";
  #   mode = "0400";
  # };

  # Required for Docker networking between containers
  boot.kernel.sysctl."net.ipv4.ip_forward" = true;
  virtualisation.docker.enable = true;

  services.gitlab-runner = {
    enable = true;
    # Max number of jobs running simultaneously across all runners
    settings.concurrent = 20;

    services.nix = {
      # Token file should contain:
      #   CI_SERVER_URL=https://gitlab.com
      #   CI_SERVER_TOKEN=glrt-xxxxxxxxxxxxxxxxxxxx
      #
      # Create runner in GitLab UI: Settings > CI/CD > Runners > New project runner
      # The token file must be created manually at this path (persists across reboots).
      # When sops-nix is wired up, switch to the commented line below.
      # authenticationTokenConfigFile = config.sops.secrets."gitlab-runner-token".path;
      authenticationTokenConfigFile = "/etc/gitlab-runner/token-env";

      # Ubuntu provides bash as /bin/sh, which is required for `nix print-dev-env` output.
      # Do not use alpine — its ash shell can't parse the bash functions nix emits.
      dockerImage = "ubuntu:latest";

      # Mount the host's Nix store, database, and daemon socket into every container.
      # This lets CI jobs run nix commands via the host's nix-daemon without a full
      # nix installation in the image. The store and DB are read-only; the daemon
      # socket allows building derivations on the host.
      dockerVolumes = [
        "/nix/store:/nix/store:ro"
        "/nix/var/nix/db:/nix/var/nix/db:ro"
        "/nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket:ro"
        # Persistent cache directory — survives container restarts so gradle,
        # npm, etc. caches are reused across jobs
        "/srv/gitlab-runner/cache:/cache"
      ];
      dockerDisableCache = true;

      # Runs before every job's script. Sets up the Nix directory structure and
      # installs essential tools (nix, git, openssh, cacert) into the container.
      # Uses full Nix store paths (e.g. ${pkgs.coreutils}/bin/mkdir) so it works
      # in any image regardless of what's on PATH.
      # Kaniko is skipped — it snapshots the filesystem between steps and would
      # capture the nix setup into the built image.
      preBuildScript = pkgs.writeScript "setup-container" ''
        # Kaniko snapshots the filesystem for image layers — skip nix setup
        # to avoid polluting the built image with nix artifacts
        if [ -f /kaniko/executor ]; then
          exit 0
        fi

        # Create required Nix directory structure — nix-daemon expects these to exist
        ${pkgs.coreutils}/bin/mkdir -p -m 0755 /nix/var/log/nix/drvs
        ${pkgs.coreutils}/bin/mkdir -p -m 0755 /nix/var/nix/gcroots
        ${pkgs.coreutils}/bin/mkdir -p -m 0755 /nix/var/nix/profiles
        ${pkgs.coreutils}/bin/mkdir -p -m 0755 /nix/var/nix/temproots
        ${pkgs.coreutils}/bin/mkdir -p -m 0755 /nix/var/nix/userpool
        ${pkgs.coreutils}/bin/mkdir -p -m 1777 /nix/var/nix/gcroots/per-user
        ${pkgs.coreutils}/bin/mkdir -p -m 1777 /nix/var/nix/profiles/per-user
        ${pkgs.coreutils}/bin/mkdir -p -m 0755 /nix/var/nix/profiles/per-user/root
        ${pkgs.coreutils}/bin/mkdir -p -m 0700 "$HOME/.nix-defexpr"

        # Source nix profile and install essential tools into the container
        . ${pkgs.nix}/etc/profile.d/nix.sh
        ${pkgs.nix}/bin/nix-env -i ${lib.concatStringsSep " " (with pkgs; [nix cacert git openssh])} > /dev/null 2>&1
      '';

      environmentVariables = {
        ENV = "/etc/profile";
        USER = "root";
        # Delegate all store operations to the host's nix-daemon via the mounted socket
        NIX_REMOTE = "daemon";
        # Enable flakes and the `nix` command (nix develop, nix build, etc.)
        NIX_CONFIG = "experimental-features = nix-command flakes";
        # Nix profiles prepended, then all standard FHS paths so any image's
        # tools are found, plus /busybox for kaniko
        PATH = "/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/busybox";
        # Required for nix to verify HTTPS connections (e.g. fetching flake inputs)
        NIX_SSL_CERT_FILE = "/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt";
      };

      tagList = ["nix"];
    };
  };
}
