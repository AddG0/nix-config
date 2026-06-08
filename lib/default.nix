{lib, ...}: let
  frontmatter = import ./frontmatter.nix {inherit lib;};
in {
  # genK3sAgentModule = import ./genK3sAgentModule.nix;
  # genK3sServerModule = import ./genK3sServerModule.nix;

  inherit frontmatter;
  ai = import ./ai {
    inherit frontmatter lib;
  };

  # use path relative to the root of the project
  relativeToRoot = lib.path.append ../.;
  relativeToHome = lib.path.append ../home;
  relativeToHosts = lib.path.append ../hosts;

  # Generate a network connectivity check function for shell scripts
  # Usage in writeShellScript: ${lib.custom.mkNetworkWaitScript { pkgs = pkgs; host = "github.com"; }}
  # Usage in writeShellApplication: ${lib.custom.mkNetworkWaitScript { host = "github.com"; }} (ping is in runtimeInputs)
  mkNetworkWaitScript = {
    pkgs ? null, # Required for writeShellScript, optional for writeShellApplication
    host ? "1.1.1.1", # Cloudflare DNS - reliable default
    maxAttempts ? 30,
    waitSeconds ? 2,
  }: let
    pingCmd =
      if pkgs != null
      then "${pkgs.iputils}/bin/ping"
      else "ping";
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

  # The shim — not `source` — is what lands in each repo's .git/hooks/ at
  # clone time. Editing `source` afterward updates all repos via the shim's
  # exec indirection. Requires `init.templateDir` (set in home/common/core/git.nix).
  mkGitTemplateHook = {
    pkgs,
    name,
    source,
  }: {
    xdg.configFile = {
      "git/template/hooks/${name}" = {
        source = pkgs.writeShellScript "${name}-shim" ''
          exec "''${XDG_CONFIG_HOME:-$HOME/.config}/git/hooks/${name}" "$@"
        '';
        executable = true;
      };
      "git/hooks/${name}" = {
        inherit source;
        executable = true;
      };
    };
  };

  # Resolve one or more template names from a gitignore source tree (e.g. the
  # github/gitignore repo as a flake input) into a flat list of ignore lines
  # suitable for home-manager's `programs.git.ignores`.
  # Usage: gitignoreFromTemplates inputs.github-gitignore-templates ["Nix" "Global/Agents"]
  gitignoreFromTemplates = source: names:
    lib.concatMap (name:
      lib.filter (s: s != "") (lib.splitString "\n" (builtins.readFile
          "${source}/${name}.gitignore")))
    names;

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
