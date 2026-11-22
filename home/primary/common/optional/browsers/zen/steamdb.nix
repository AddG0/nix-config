# Zen space for the SteamDB extension, with its free-packages and store pins.
let
  space = "e05ebbb1-e21c-4621-b668-5f6296afb5e3";
in {
  programs.zen-browser.profiles.default = {
    # No container: SteamDB reads Steam's login from the default cookie store only.
    spaces."SteamDB" = {
      id = space;
      icon = "chrome://browser/skin/zen-icons/selectable/game-controller.svg";
      position = 3000;
    };
    pins = {
      "SteamDB Free Packages" = {
        id = "37ddada0-bc76-4d52-917d-f7968e61aa34";
        url = "https://steamdb.info/freepackages/";
        position = 12000;
        workspace = space;
      };
      "Steam Store" = {
        id = "89beb667-f5e0-4a98-9299-6d496bcbb544";
        url = "https://store.steampowered.com";
        position = 13000;
        workspace = space;
      };
    };
  };
}
