# One Noctalia plugin dir -> its xdg.dataFile entries. Files named in `templates` are
# replaceVars'd: runAsync's PATH is noctalia's own, so binaries must be baked in absolute.
{
  pkgs,
  lib,
}: {
  dir,
  name ? baseNameOf dir,
  files ? ["${name}.luau"],
  templates ? {},
}: let
  base = "noctalia/plugins/${name}";
  translations = dir + "/translations/en.json";
in
  {"${base}/plugin.toml".source = dir + "/plugin.toml";}
  // builtins.listToAttrs (map (file:
    lib.nameValuePair "${base}/${file}" {
      source =
        if templates ? ${file}
        then pkgs.replaceVars (dir + "/${file}") templates.${file}
        else dir + "/${file}";
    })
  files)
  // lib.optionalAttrs (builtins.pathExists translations) {
    "${base}/translations/en.json".source = translations;
  }
