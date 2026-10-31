# games.nix entries as steam-config-nix apps: a game's `reshade` setup applies everywhere, or with `optIn` only
# where the host lists it. On a shared-library host, files placed in game folders go to `libraryFiles` for the
# host's single writer instead of to each user's steam-config-nix.
{
  lib,
  reshade,
  writeText,
}: {
  games,
  reshadeGames,
  sharedLibrary,
}: let
  missing = lib.filter (slug: !(games.${slug} or {} ? reshade)) reshadeGames;

  withReshade = slug: app: let
    base = removeAttrs app ["reshade"];
  in
    if app ? reshade && (!(app.reshade.optIn or false) || lib.elem slug reshadeGames)
    then lib.recursiveUpdate base (reshade (removeAttrs app.reshade ["optIn"]))
    else base;

  apps = lib.mapAttrs withReshade games;

  # The operations steam-config-nix's own module would build from files.game.place (steam-app-files.nix mkFileOps).
  normalise = path: lib.concatStringsSep "/" (lib.filter (part: part != "" && part != ".") (lib.splitString "/" path));
  # Its submodule checks no longer see these entries, so the same rules are enforced here.
  gameFileOps = app:
    lib.mapAttrsToList (name: entry: let
      source = entry.source or null;
      text = entry.text or null;
      mode = entry.mode or "enforce";
      where = "app ${toString app.id} files.game.place.\"${name}\"";
    in
      lib.throwIf ((source == null) == (text == null)) "${where}: set exactly one of source or text"
      (lib.throwIfNot (lib.elem mode ["enforce" "seed" "lock"]) "${where}: mode must be enforce, seed or lock, not ${mode}" {
        appId = app.id;
        target = normalise (entry.target or name);
        source = "${
          if source != null
          then source
          else writeText "steam-config-nix-file" text
        }";
        inherit mode;
        executable = entry.executable or null;
      })) (lib.filterAttrs (_: entry: entry.enable or true) (app.files.game.place or {}));

  withoutGamePlacements = app:
    if app ? files.game.place
    then app // {files = app.files // {game = removeAttrs app.files.game ["place"];};}
    else app;
in
  lib.throwIf (missing != [])
  "gaming.steam.reshade: no reshade setup in steam/games.nix for ${lib.concatStringsSep ", " missing}"
  (
    if sharedLibrary
    then {
      apps = lib.mapAttrs (_: withoutGamePlacements) apps;
      libraryFiles = lib.concatMap gameFileOps (lib.attrValues apps);
    }
    else {
      inherit apps;
      libraryFiles = [];
    }
  )
