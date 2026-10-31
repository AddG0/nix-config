# Users' shared-library game files merged into one list for the host's single writer.
{lib, ...}: let
  merge = import ../_library-files.nix {inherit lib;};

  op = target: source: {
    appId = 10;
    inherit target source;
    mode = "enforce";
    executable = null;
  };
  home = ops: {gaming.steam.libraryFiles = ops;};
in {
  "test the same file declared by two users is placed once" = {
    expr = (merge [(home [(op "dxgi.dll" "/s/dll")]) (home [(op "dxgi.dll" "/s/dll")])]).ops;
    expected = [(op "dxgi.dll" "/s/dll")];
  };

  "test files from different users are all placed" = {
    expr = map (o: o.target) (merge [(home [(op "a" "/s/a")]) (home [(op "b" "/s/b")])]).ops;
    expected = ["a" "b"];
  };

  "test one target with different contents per user is a conflict named by app and target" = {
    expr = (merge [(home [(op "dxgi.dll" "/s/one")]) (home [(op "dxgi.dll" "/s/two")])]).conflicts;
    expected = ["10/dxgi.dll"];
  };

  "test a home without the steam module contributes nothing" = {
    expr = merge [{} (home [])];
    expected = {
      ops = [];
      conflicts = [];
    };
  };
}
