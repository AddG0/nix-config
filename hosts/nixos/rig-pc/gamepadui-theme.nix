# A CSS Loader theme; the plugin picks up any folder under its themes dir.
{
  config,
  lib,
  pkgs,
  ...
}: let
  manifest = pkgs.writeText "theme.json" (builtins.toJSON {
    name = "Ultrawide Play Button";
    version = "v1.0.0";
    author = "addg";
    description = "Trims the library hero art so the Play button clears the first page on a 32:9 panel.";
    manifest_version = 9;
    inject."bigpicture.css" = ["Steam Big Picture Mode"];
  });

  # gamepadui gets a 598px viewport here, and the 505px hero art leaves the
  # Play button at 575-623 — straddling the page the UI scrolls by, so paging
  # clips it at the bottom, then at the top. 460 lands it at 578. Matched on
  # the image URL because every class in that subtree is a Steam build hash.
  css = pkgs.writeText "bigpicture.css" ''
    div:has(> div > div > img[src*="library_hero.jpg"]) {
      height: 460px !important;
      overflow: hidden;
    }
  '';
  # Read once at theme load and only rewritten by a UI toggle, so a store
  # symlink holds. _USER rather than _ROOT because decky runs as the login
  # user (decky-follow-user in gaming/decky).
  enabledState = pkgs.writeText "config_USER.json" (builtins.toJSON {active = true;});

  # Each user's DECKY_HOME, whose decky dir gaming/decky creates.
  rulesFor = user: let
    inherit (config.users.users.${user}) home group;
    themes = "${home}/.local/share/decky/themes";
    themeDir = "${themes}/UltrawidePlayButton";
  in [
    "d ${themes} 0755 ${user} ${group} -"
    "d ${themeDir} 0755 ${user} ${group} -"
    "L+ ${themeDir}/theme.json - - - - ${manifest}"
    "L+ ${themeDir}/bigpicture.css - - - - ${css}"
    "L+ ${themeDir}/config_USER.json - - - - ${enabledState}"
  ];
in {
  # CSS Loader writes into the theme folder, so it cannot be a store symlink.
  systemd.tmpfiles.rules =
    lib.concatMap rulesFor config.hostSpec.users
    # The copy from when themes were shared; any other theme there moves to the boot user's.
    ++ ["R ${config.jovian.decky-loader.stateDir}/themes/UltrawidePlayButton"];
}
