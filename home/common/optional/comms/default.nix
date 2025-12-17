{pkgs, ...}: let
  # Fix Slack desktop file name for KDE Wayland (must be "Slack.desktop" not "slack.desktop")
  slackFixed = pkgs.slack.overrideAttrs (oldAttrs: {
    postInstall =
      (oldAttrs.postInstall or "")
      + ''
        if [ -f "$out/share/applications/slack.desktop" ]; then
          mv "$out/share/applications/slack.desktop" "$out/share/applications/Slack.desktop"
        fi
      '';
  });
in {
  home.packages =
    if pkgs.stdenv.isLinux
    then [slackFixed pkgs.discord-legcord]
    else [pkgs.slack pkgs.discord];
}
