# Each user's gaming.steam.libraryFiles merged into the one list the host places; a target declared twice with
# different contents is a conflict, named as `<app id>/<target>`.
{lib}: homes: let
  ops = lib.unique (lib.concatMap (home: home.gaming.steam.libraryFiles or []) homes);
  byTarget = lib.groupBy (op: "${toString op.appId}/${op.target}") ops;
in {
  inherit ops;
  conflicts = lib.attrNames (lib.filterAttrs (_: declared: lib.length declared > 1) byTarget);
}
