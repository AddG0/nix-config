# The packages our overlays define or patch in a host's package set, found from where each overlay sets an attribute.
{lib}: {
  inputs,
  pkgs,
  # Substrings of overlay paths (relative to overlays/); keeps the targets a matching overlay patches, empty keeps all.
  filters ? [],
  # The overlay files to read; the ones default.nix composes on this platform unless a test passes its own.
  files ? (import ./overlay-files.nix {inherit lib;}).on pkgs.stdenv.hostPlatform,
}: let
  relativePath = file: lib.removePrefix "${toString ./.}/" (toString file);
  matches = file: filters == [] || lib.any (filter: lib.hasInfix filter (relativePath file)) filters;

  # An attribute passed through from prev keeps the position of wherever it was first set.
  setsItself = file: attrs: attr: (builtins.unsafeGetAttrPos attr attrs).file or null == toString file;

  # A value that throws (a package removed upstream) counts as a package, so its build reports the error; tryEval cannot catch a missing attribute.
  attrPathsSetBy = file: prefix: attrs:
    lib.concatMap (attr: let
      value = attrs.${attr};
      attrPath = prefix ++ [attr];
      drvCheck = builtins.tryEval (lib.isDerivation value);
      nested = attrPathsSetBy file attrPath value;
    in
      if !setsItself file attrs attr
      then []
      else if !drvCheck.success || drvCheck.value
      then [
        {
          inherit file attrPath;
          isPackage = true;
        }
      ]
      else if builtins.isAttrs value && nested != []
      then nested
      else [
        {
          inherit file attrPath;
          isPackage = false;
        }
      ])
    (builtins.attrNames attrs);

  # A workaround's `# CHECK-ATTR:` line names the package to build when the overlay sets no package itself, e.g. a whole replaced package set.
  checkAttrs = file:
    lib.concatMap (line: let
      attr = builtins.match "# *CHECK-ATTR: *([^ ]+) *" line;
    in
      lib.optional (attr != null) (lib.splitString "." (lib.head attr)))
    (lib.splitString "\n" (builtins.readFile file));
  foundIn = file: let
    entries = attrPathsSetBy file [] ((import file {inherit inputs;}) pkgs pkgs);
    declared = map (attrPath: {
      inherit file attrPath;
      isPackage = true;
    }) (checkAttrs file);
  in
    if lib.any (entry: !entry.isPackage) entries && declared != []
    then lib.filter (entry: entry.isPackage) entries ++ declared
    else entries;

  # Read from every file, so a kept target names every overlay that patches it.
  found = lib.concatMap foundIn files;
  # Quoted like nix-eval-jobs names attributes, so build results match their targets.
  dotted = entry: lib.concatMapStringsSep "." lib.strings.escapeNixIdentifier entry.attrPath;
  byTarget = lib.filterAttrs (_: lib.any (entry: matches entry.file)) (lib.groupBy dotted (lib.filter (entry: entry.isPackage) found));

  # nix-eval-jobs only descends into sets marked recurseForDerivations.
  nest = attrPath: drv:
    if lib.length attrPath == 1
    then {${lib.head attrPath} = drv;}
    else {${lib.head attrPath} = {recurseForDerivations = true;} // nest (lib.tail attrPath) drv;};
in {
  targets = lib.foldl' lib.recursiveUpdate {} (lib.mapAttrsToList (_: entries: let
    inherit (lib.head entries) attrPath;
  in
    nest attrPath (lib.getAttrFromPath attrPath pkgs))
  byTarget);
  overlaysByTarget = lib.mapAttrs (_: map (entry: relativePath entry.file)) byTarget;
  nonPackageAttrPaths = map (entry: "${relativePath entry.file}: ${dotted entry}") (lib.filter (entry: !entry.isPackage && matches entry.file) found);
  # Kept files that set nothing here: guarded to another platform, or re-exporting a flake input's overlay.
  overlaysSettingNothing = map relativePath (lib.filter (file: matches file && !lib.any (entry: entry.file == file) found) files);
}
