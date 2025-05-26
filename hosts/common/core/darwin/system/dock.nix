{
  pkgs,
  config,
  ...
}: {
  # customize dock
  system.defaults.dock = {
    autohide = true; # automatically hide and show the dock
    show-recents = true; # do not show recent apps in dock
    # do not automatically rearrange spaces based on most recent use.
    mru-spaces = true;
    expose-group-apps = true; # Group windows by application
    enable-spring-load-actions-on-all-items = true;
    appswitcher-all-displays = false;

    # customize Hot Corners(触发角, 鼠标移动到屏幕角落时触发的动作)
    wvous-tl-corner = 2; # top-left - Mission Control
    wvous-tr-corner = 4; # top-right - Desktop
    wvous-bl-corner = 3; # bottom-left - Application Windows
    wvous-br-corner = 13; # bottom-right - Lock Screen

    persistent-apps = [
      "/Applications/Arc.app"
      "${pkgs.jetbrains.idea-ultimate}/Applications/IntelliJ IDEA.app"
      "/Applications/Cursor.app"
      "${pkgs.postman}/Applications/Postman.app"
      "${pkgs.slack}/Applications/Slack.app"
      "${pkgs.discord}/Applications/Discord.app"
      "${pkgs.lens}/Applications/Lens.app"
      "/Users/${config.hostSpec.username}/Applications/Home Manager Apps/Spotify.app"
    ];
  };
}
