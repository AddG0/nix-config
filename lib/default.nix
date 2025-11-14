{lib, ...}: {
  # genK3sAgentModule = import ./genK3sAgentModule.nix;
  # genK3sServerModule = import ./genK3sServerModule.nix;

  genUser = import ./user/genUser.nix;

  # use path relative to the root of the project
  relativeToRoot = lib.path.append ../.;
  relativeToHome = lib.path.append ../home;
  relativeToHosts = lib.path.append ../hosts;

  # Generate a network connectivity check function for shell scripts
  # Usage in writeShellScript: ${lib.custom.mkNetworkWaitScript { pkgs = pkgs; host = "github.com"; }}
  # Usage in writeShellApplication: ${lib.custom.mkNetworkWaitScript { host = "github.com"; }} (ping is in runtimeInputs)
  mkNetworkWaitScript = {
    pkgs ? null,  # Required for writeShellScript, optional for writeShellApplication
    host ? "1.1.1.1",  # Cloudflare DNS - reliable default
    maxAttempts ? 30,
    waitSeconds ? 2,
  }: let
    pingCmd = if pkgs != null then "${pkgs.iputils}/bin/ping" else "ping";
  in ''
    wait_for_network() {
      local max_attempts=${toString maxAttempts}
      local attempt=1

      while [ $attempt -le $max_attempts ]; do
        if ${pingCmd} -c 1 -W 2 ${host} >/dev/null 2>&1; then
          log "Network connectivity confirmed (reached ${host})"
          return 0
        fi
        log "Waiting for network connectivity (attempt $attempt/$max_attempts)..."
        sleep ${toString waitSeconds}
        ((attempt++))
      done

      log "ERROR: Network connectivity timeout after $max_attempts attempts"
      return 1
    }

    # Wait for network before proceeding
    wait_for_network || exit 1
  '';

  scanPaths = path:
    builtins.map (f: (path + "/${f}")) (
      builtins.attrNames (
        lib.attrsets.filterAttrs (
          path: _type:
            (_type == "directory" && path != "darwin" && path != "nixos") # include directories except darwin/nixos
            || (
              path
              != "default.nix" # ignore default.nix
              && (lib.strings.hasSuffix ".nix" path) # include .nix files
            )
        ) (builtins.readDir path)
      )
    );

  scanPackages = path:
    builtins.map (f: (path + "/${f}")) (
      builtins.attrNames (
        lib.attrsets.filterAttrs (
          path: _type: (_type == "directory" && path != "darwin" && path != "nixos") # include directories except darwin/nixos
        ) (builtins.readDir path)
      )
    );
}
