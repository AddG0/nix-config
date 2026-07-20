{
  pkgs,
  lib,
  ...
}: let
  # One Noctalia plugin dir -> its xdg.dataFile entries. The entry .luau is
  # replaceVars'd when substitutions are given: runAsync inherits no PATH, so
  # binaries the script shells out to must be baked in as absolute paths.
  # Enabling + bar placement stay in ../default.nix.
  mkPlugin = {
    name,
    entry ? "${name}.luau",
    substitutions ? {},
  }: let
    dir = ./. + "/${name}";
    base = "noctalia/plugins/${name}";
    translations = dir + "/translations/en.json";
  in
    {
      "${base}/plugin.toml".source = dir + "/plugin.toml";
      "${base}/${entry}".source =
        if substitutions == {}
        then dir + "/${entry}"
        else pkgs.replaceVars (dir + "/${entry}") substitutions;
    }
    // lib.optionalAttrs (builtins.pathExists translations) {
      "${base}/translations/en.json".source = translations;
    };
in {
  xdg.dataFile =
    mkPlugin {
      name = "next-event";
      substitutions = {
        noctalia = lib.getExe pkgs.noctalia;
        jq = lib.getExe pkgs.jq;
      };
    }
    // mkPlugin {
      name = "otd-mode";
      substitutions = {
        otd = "${pkgs.opentabletdriver}/bin/otd";
        journalctl = "${pkgs.systemd}/bin/journalctl";
      };
    };
}
