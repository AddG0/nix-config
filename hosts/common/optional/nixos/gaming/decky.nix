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
    # Retargets the injector to the debugger port gaming/steam.nix launches Steam with, and gives plugins the user's groups.
    package = pkgs.jovianPackages.decky-loader.overrideAttrs (o: {
      postFixup =
        (o.postFixup or "")
        + ''
          for site in $out/lib/python*/site-packages/decky_loader; do
            substituteInPlace "$site/injector.py" \
              --replace-fail "http://localhost:8080" "http://localhost:21379"
            # Plugins drop to the user without its supplementary groups, so a Steam they launch can't reach a group-only library.
            substituteInPlace "$site/localplatform/localplatformlinux.py" \
              --replace-fail "-iTCP:8080" "-iTCP:21379" \
              --replace-fail "os.setgid(host_user_group_id)" "os.initgroups(_get_user(), host_user_group_id); os.setgid(host_user_group_id)"
          done
          # drop stale bytecode so the edits take effect at runtime
          find "$out" -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null || true
        '';
    });
    # Run as the autologin user so plugins reach its session's dbus/pipewire.
    user = config.hostSpec.primaryDesktopUsername;
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
      Deckify = customPkgs.decky.deckify;
      decky-steamgriddb = customPkgs.decky.steamgriddb;
      protondb-decky = customPkgs.decky.protondb-badges;
      TabMaster = customPkgs.decky.tabmaster;
      hltb-for-deck = customPkgs.decky.hltb;
      SDH-CssLoader = customPkgs.decky.css-loader;
      DisplaySettings = customPkgs.decky.gamescope-display;
    };
  };

  systemd.services.decky-loader.environment = {
    # Doubles up on extraPackages above: a plugin subprocess may get a narrower
    # environment than the loader's PATH.
    GAMESCOPE_SET_DISPLAY = lib.getExe config.gaming.gamescopeSession.displayTool;
    # Bare hostname the LAN's DNS already answers for; set networking.domain to advertise an FQDN instead.
    DECKIFY_ADVERTISED_HOST = config.networking.fqdnOrHostName;
    # One household Spotify app; its dashboard lists https://<host>:39281/callback for each host.
    DECKIFY_SPOTIFY_CLIENT_ID = "5495bd441a014dbc8ea6391baf1d670b";
  };

  # Deckify's Spotify OAuth page, so its login QR code reaches a phone.
  networking.firewall.allowedTCPPorts = [39281];

  # decky-loader's frontend builds with pnpm (build-time only, not runtime).
  nixpkgs.config.permittedInsecurePackages = ["pnpm-9.15.9"];
}
