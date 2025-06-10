{lib, ...}: {
  # genK3sAgentModule = import ./genK3sAgentModule.nix;
  # genK3sServerModule = import ./genK3sServerModule.nix;

  genUser = import ./user/genUser.nix;

  # use path relative to the root of the project
  relativeToRoot = lib.path.append ../.;
  relativeToHome = lib.path.append ../home;
  relativeToHosts = lib.path.append ../hosts;

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
