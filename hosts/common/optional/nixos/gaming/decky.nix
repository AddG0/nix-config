{
  inputs,
  config,
  lib,
  pkgs,
  customPkgs,
  ...
}: {
  imports = [inputs.jovian.nixosModules.default];

  jovian.decky-loader = {
    enable = true;
    # Run as the logged-in user so plugins reach their session — Deckcord's voice
    # backend hardcodes /run/user/1000 (dbus/pipewire). Plugins run as you.
    user = config.hostSpec.primaryUsername;
    extraPackages = [
      pkgs.systemd # decky shells out to `systemctl`
      config.gaming.gamescopeSession.displayTool
    ];
    extraPythonPackages = ps: [ps.aiohttp-cors]; # Deckcord backend imports it
    # Plugins are pinned here, so both update notifications are dead ends.
    settings.notificationSettings = {
      pluginUpdates = false;
      deckyUpdates = false;
    };
    # Keys are the store's own folder names, so a UI install wouldn't duplicate.
    plugins = {
      Deckcord = customPkgs.decky.deckcord;
      # Bare hostname the LAN's DNS already answers for; set networking.domain
      # to advertise an FQDN instead.
      Deckify = customPkgs.decky.deckify.override {advertisedHost = config.networking.fqdnOrHostName;};
      decky-steamgriddb = customPkgs.decky.steamgriddb;
      protondb-decky = customPkgs.decky.protondb-badges;
      TabMaster = customPkgs.decky.tabmaster;
      hltb-for-deck = customPkgs.decky.hltb;
      SDH-CssLoader = customPkgs.decky.css-loader;
      DisplaySettings = customPkgs.decky.gamescope-display;
    };
  };

  # Doubles up on extraPackages above: a plugin subprocess may get a narrower
  # environment than the loader's PATH.
  systemd.services.decky-loader.environment.GAMESCOPE_SET_DISPLAY =
    lib.getExe config.gaming.gamescopeSession.displayTool;

  # Deckify's Spotify OAuth page, so its login QR code reaches a phone.
  networking.firewall.allowedTCPPorts = [39281];

  # decky-loader's frontend builds with pnpm (build-time only, not runtime).
  nixpkgs.config.permittedInsecurePackages = ["pnpm-9.15.9"];
}
