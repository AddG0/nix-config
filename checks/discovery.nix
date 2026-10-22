# Finds every test under the given roots and names it `<kind>:<area>[:<sub>]`; anything in a tests dir that would not run throws.
{lib}: let
  kindOf = {
    "unit.nix" = "unit";
    "structure.nix" = "unit";
    "files.nix" = "files";
    "script.nix" = "script";
  };

  isHelper = name: lib.hasPrefix "_" name;

  # roots: name to {path, qualifier}; a null qualifier is the module tree, whose areas are bare.
  # readDir is injected so the rules can be tested on an in-memory tree.
  discover = {
    roots,
    readDir ? builtins.readDir,
  }: let
    stray = path: reason: throw "checks/discovery.nix: ${toString path}: ${reason}";

    # A subdirectory of a tests dir holds data only (fixtures/): no .nix file, no symlink, at any depth.
    dataDir = dir:
      lib.concatMap (name: let
        path = dir + "/${name}";
        type = (readDir dir).${name};
      in
        if type == "directory"
        then dataDir path
        else if type != "regular"
        then [(stray path "a tests dir holds no ${type}; discovery would not follow it")]
        else if lib.hasSuffix ".nix" name
        then [(stray path "a subdirectory of a tests dir holds data only, so this .nix file would never run; move it up into the tests dir")]
        else [])
      (lib.attrNames (readDir dir));

    # The entries of a tests dir that are neither files nor data dirs, as throws.
    unreadable = dir: let
      entries = readDir dir;
    in
      lib.concatMap (name:
        if entries.${name} == "directory"
        then dataDir (dir + "/${name}")
        else if entries.${name} != "regular"
        then [(stray (dir + "/${name}") "a tests dir holds no ${entries.${name}}; discovery would not follow it")]
        else [])
      (lib.attrNames entries);

    suitesOrThrow = dir: suites:
      builtins.deepSeq (unreadable dir) (
        if suites == []
        then stray dir "a tests dir yields no suite, only helpers and data; add a unit.nix, structure.nix, files.nix or script.nix"
        else suites
      );

    testsIn = dir: segments: let
      entries = readDir dir;
      nixFiles = lib.filter (name: entries.${name} == "regular" && lib.hasSuffix ".nix" name && !isHelper name) (lib.attrNames entries);
    in
      suitesOrThrow dir (map (file:
        if kindOf ? ${file}
        then {
          name = lib.concatStringsSep ":" ([kindOf.${file}] ++ segments ++ lib.optional (file == "structure.nix") "structure");
          kind = kindOf.${file};
          file = dir + "/${file}";
        }
        else stray (dir + "/${file}") "a tests dir holds only unit.nix, structure.nix, files.nix, script.nix, `_` helpers and data")
      nixFiles);

    testsKind = dir: entries:
      if entries.tests or null == "symlink"
      then stray (dir + "/tests") "a tests dir must be a directory, not a symlink"
      else entries.tests or null == "directory";

    # `area`: the nearest tested ancestor's segments, so a nested module is named under it.
    walk = dir: area: let
      entries = readDir dir;
      hasTests = testsKind dir entries;
      here =
        if hasTests
        then area ++ [(baseNameOf dir)]
        else area;
      children = lib.filter (name: entries.${name} == "directory" && name != "tests" && !lib.hasPrefix "." name) (lib.attrNames entries);
    in
      lib.optional (entries ? "tests.nix") (stray (dir + "/tests.nix") "tests live in tests/<kind>.nix")
      ++ lib.optionals hasTests (testsIn (dir + "/tests") here)
      ++ lib.concatMap (name: walk (dir + "/${name}") here) children;

    # A root's own tests/ holds one area per file when the root is flat (lib/), else the root is one area.
    fromRoot = _: {
      path,
      qualifier,
      flat ? false,
    }:
      if flat
      then let
        dir = path + "/tests";
        entries = readDir dir;
        files = lib.filter (name: entries.${name} == "regular" && lib.hasSuffix ".nix" name && !isHelper name) (lib.attrNames entries);
        rootEntries = readDir path;
        rest = lib.filter (name: rootEntries.${name} == "directory" && name != "tests" && !lib.hasPrefix "." name) (lib.attrNames rootEntries);
      in
        builtins.seq (testsKind path rootEntries) (suitesOrThrow dir (map (file: {
            name = "unit:${qualifier}:${lib.removeSuffix ".nix" file}";
            kind = "unit";
            file = dir + "/${file}";
          })
          files))
        ++ lib.concatMap (name: walk (path + "/${name}") [qualifier]) rest
      else let
        entries = readDir path;
        children = lib.filter (name: entries.${name} == "directory" && name != "tests" && !lib.hasPrefix "." name) (lib.attrNames entries);
        base = lib.optional (qualifier != null) qualifier;
      in
        lib.optionals (testsKind path entries) (testsIn (path + "/tests") base)
        ++ lib.concatMap (name: walk (path + "/${name}") base) children;

    found = lib.concatLists (lib.mapAttrsToList fromRoot roots);
    duplicates = lib.filter (name: lib.count (test: test.name == name) found > 1) (lib.unique (map (test: test.name) found));
  in
    lib.throwIf (duplicates != [])
    "checks/discovery.nix: two tests share a name: ${lib.concatMapStringsSep "; " (name: "${name} (${lib.concatMapStringsSep ", " (test: toString test.file) (lib.filter (test: test.name == name) found)})") duplicates}"
    found;

  # nix-unit runs only `test*` attributes, descending into every other attrset.
  testCount = suite:
    lib.foldl' (count: name:
      count
      + (
        if lib.hasPrefix "test" name
        then 1
        else if lib.isAttrs suite.${name}
        then testCount suite.${name}
        else 0
      ))
    0 (lib.attrNames suite);

  withTests = test: suite: lib.throwIf (testCount suite == 0) "checks/discovery.nix: ${toString test.file}: ${test.name} has no `test*` attribute, so nix-unit would run nothing and pass" suite;
in {
  inherit discover kindOf testCount withTests;
}
