{
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    # If it says "Corrective action is required to continue" Open Epic Games in the browser
    # https://www.reddit.com/r/SteamDeck/comments/1hu9242/heroic_launcher_login_error/
    heroic
  ];
}
