# games.nix entries as steam-config-nix apps: a game's `reshade` setup applies everywhere, or with `optIn` only
# where the host lists it.
{
  lib,
  reshade,
}: {
  games,
  reshadeGames,
}: let
  missing = lib.filter (slug: !(games.${slug} or {} ? reshade)) reshadeGames;

  withReshade = slug: app: let
    base = removeAttrs app ["reshade"];
  in
    if app ? reshade && (!(app.reshade.optIn or false) || lib.elem slug reshadeGames)
    then lib.recursiveUpdate base (reshade (removeAttrs app.reshade ["optIn"]))
    else base;
in
  lib.throwIf (missing != [])
  "gaming.steam.reshade: no reshade setup in steam/games.nix for ${lib.concatStringsSep ", " missing}"
  (lib.mapAttrs withReshade games)
