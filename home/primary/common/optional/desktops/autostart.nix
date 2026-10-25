# Apps that start with every desktop session on any host; hosts add their own on top.
{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  # Hosts with spicetify start its patched Spotify; the rest start stock.
  spotify =
    if options.programs ? spicetify && config.programs.spicetify.enable
    then config.programs.spicetify.spicedSpotify
    else pkgs.spotify;
in {
  xdg.autostart = {
    enable = true;
    entries = [
      "${pkgs.discord}/share/applications/discord.desktop"
      "${pkgs._1password-gui}/share/applications/com.onepassword.OnePassword.desktop"
      "${spotify}/share/applications/spotify.desktop"
    ];
  };
}
