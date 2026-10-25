{lib, ...}: {
  options.gaming.windowClasses = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    example = ["^(steam_app_[0-9]+)$"];
    description = "Regexes for game windows' X11 class or Wayland app-id; compositor rules and guards treat a match as a game.";
  };
}
