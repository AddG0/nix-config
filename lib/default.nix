{
  lib,
  pkgs ? {
    stdenv.isLinux = false;
    stdenv.isDarwin = false;
  }, # TODO: clean this up
  configVars,
  ...
}: {
  macosSystem = import ./macosSystem.nix;
  nixosSystem = import ./nixosSystem.nix;

  # use path relative to the root of the project
  relativeToRoot = lib.path.append ../.;
  relativeToHome = lib.path.append ../home;
  relativeToHosts = lib.path.append ../hosts;
  # Function to get the home directory based on the OS
  getHomeDirectory = username:
    if pkgs.stdenv.isLinux
    then "/home/${username}"
    else "/Users/${username}";

  scanPaths = path:
    builtins.map (f: (path + "/${f}")) (
      builtins.attrNames (
        lib.attrsets.filterAttrs (
          path: _type:
            (_type == "directory") # include directories
            || (
              (path != "default.nix") # ignore default.nix
              && (lib.strings.hasSuffix ".nix" path) # include .nix files
            )
        ) (builtins.readDir path)
      )
    );
}
