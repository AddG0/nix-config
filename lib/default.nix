{lib, ...}: let
  frontmatter = import ./frontmatter.nix {inherit lib;};

  # by-name for modules: a .nix file or a dir with default.nix is a leaf (its path); any other dir is a namespace; `_*` is private.
  moduleTree = dir:
    lib.mapAttrs' (name: type: let
      path = dir + "/${name}";
    in
      lib.nameValuePair (lib.removeSuffix ".nix" name) (
        if type == "directory" && !builtins.pathExists (path + "/default.nix")
        then moduleTree path
        else path
      ))
    (lib.filterAttrs (name: type:
      !(lib.hasPrefix "_" name)
      && (type == "directory" || (lib.hasSuffix ".nix" name && name != "default.nix" && name != "tests.nix")))
    (builtins.readDir dir));

  trees = {
    hosts = ../hosts/common/optional;
    home = ../home/common/optional;
    primary = ../home/primary/common/optional;
  };

  optional = lib.mapAttrs (_: moduleTree) trees;

  # `_suites.nix` sits in the namespace holding its members; each returns `{ <suite>.<nixos|home> = [...]; }`.
  suiteFiles = dir: let
    entries = builtins.readDir dir;
  in
    lib.optional (entries ? "_suites.nix") (dir + "/_suites.nix")
    ++ lib.concatLists (lib.mapAttrsToList (name: type:
      lib.optionals (type == "directory" && !lib.hasPrefix "_" name && !builtins.pathExists (dir + "/${name}/default.nix"))
      (suiteFiles (dir + "/${name}")))
    entries);

  mergeSuites = acc: file:
    acc
    // lib.mapAttrs (name: halves: let
      prev = acc.${name} or {};
      dup = builtins.attrNames (builtins.intersectAttrs prev halves);
    in
      if dup == []
      then prev // halves
      else throw "suite ${name}: ${lib.concatStringsSep ", " dup} defined in more than one _suites.nix")
    file;

  suites = lib.fix (self:
    builtins.foldl' mergeSuites {} (map (f:
      import f {
        inherit optional;
        suites = self;
      }) (lib.concatMap suiteFiles (lib.attrValues trees))));
in {
  inherit optional suites;

  # A host import for a suite: its nixos half, plus its home half for the primary user.
  useSuite = suite:
    (suite.nixos or [])
    ++ lib.optional (suite ? home) ({config, ...}: {
      home-manager.users.${config.hostSpec.primaryUsername}.imports = suite.home;
    });

  # genK3sAgentModule = import ./genK3sAgentModule.nix;
  # genK3sServerModule = import ./genK3sServerModule.nix;

  inherit frontmatter;
  colors = import ./colors.nix {inherit lib;};
  inherit (import ./eqFilterGraph.nix {inherit lib;}) eqShapes mkEqFilterGraph;
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
  }: let
    # git's templateDir copy preserves symlinks, so a symlinked shim would
    # capture a per-generation store path that dangles after nix GC. A real
    # file with a stable ~/.config exec target survives.
    shim = pkgs.writeText "${name}-shim" ''
      #!/bin/sh
      exec "''${XDG_CONFIG_HOME:-$HOME/.config}/git/hooks/${name}" "$@"
    '';
  in {
    xdg.configFile."git/hooks/${name}" = {
      inherit source;
      executable = true;
    };

    # Written via activation, not xdg.configFile, which would symlink it.
    home.activation."gitTemplateHook-${name}" = {
      after = ["writeBoundary"];
      before = [];
      data = ''
        run mkdir -p "''${XDG_CONFIG_HOME:-$HOME/.config}/git/template/hooks"
        run ${pkgs.coreutils}/bin/install -m755 ${shim} \
          "''${XDG_CONFIG_HOME:-$HOME/.config}/git/template/hooks/${name}"
      '';
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
    map (f: (path + "/${f}")) (
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
    map (f: (path + "/${f}")) (
      builtins.attrNames (
        lib.attrsets.filterAttrs (
          path: _type: (_type == "directory" && path != "darwin" && path != "nixos") # include directories except darwin/nixos
        ) (builtins.readDir path)
      )
    );
}
