# The overlay files default.nix composes, by directory, in composition order.
{lib}: let
  # An `input-packages` subdir is composed before its siblings so overlays that
  # override input-derived packages (e.g. desktop patches on `noctalia`) see
  # those packages in `prev`. Returns [] for a missing directory so platform
  # folders can be empty (only .gitkeep).
  under = dir:
    lib.optionals (builtins.pathExists dir) (
      let
        entries = builtins.readDir dir;
        filesIn = name:
        # tests/ belongs to checks/discovery.nix, never an overlay.
          if name == "tests"
          then []
          else if entries.${name} == "directory"
          then under (dir + "/${name}")
          else if lib.hasSuffix ".nix" name
          then [(dir + "/${name}")]
          else [];
        ordered =
          lib.optional (entries ? input-packages) "input-packages"
          ++ builtins.filter (n: n != "input-packages") (builtins.attrNames entries);
      in
        lib.concatMap filesIn ordered
    );

  common = under ./common;
  nixos = under ./nixos;
  darwin = under ./darwin;
  workarounds = under ./flake-update-workarounds;
in {
  inherit common nixos darwin workarounds;
  # default.nix guards nixos/ and darwin/ to their platform the same way.
  on = platform: common ++ lib.optionals platform.isLinux nixos ++ lib.optionals platform.isDarwin darwin ++ workarounds;
}
