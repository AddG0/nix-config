{
  inputs,
  config,
  lib,
  pkgs,
  customPkgs,
  ...
}: let
  cfg = config.jovian.decky-loader;
  userEnv = "/run/decky-loader/user.env";
  dataDir = user: "${config.users.users.${user}.home}/.local/share/decky";

  # Before any console login, plugins run as the autologin user with that user's data.
  bootEnv = pkgs.writeText "decky-boot.env" ''
    UNPRIVILEGED_USER=${cfg.user}
    UNPRIVILEGED_PATH=${dataDir cfg.user}
  '';
  followUser = import ./follow-user.nix {
    inherit pkgs;
    runtimeInputs = [pkgs.coreutils pkgs.getent pkgs.systemd];
  };
  followUserRule = {
    order = 13100;
    control = "optional";
    modulePath = "${config.security.pam.package}/lib/security/pam_exec.so";
    args = ["type=open_session" (lib.getExe followUser) "${bootEnv}" userEnv];
  };
  migrateSharedData = import ./migrate-shared-data.nix {inherit pkgs;};

  # Each level, so tmpfiles creates no missing parent root-owned; `-` keeps an existing dir's mode.
  dataDirRules = user: let
    inherit (config.users.users.${user}) home group;
  in
    map (dir: "d ${dir} - ${user} ${group} -") ["${home}/.local" "${home}/.local/share"]
    ++ ["d ${dataDir user} 0755 ${user} ${group} -"];
in {
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

  systemd.services.decky-loader = {
    # Override Jovian's fixed UNPRIVILEGED_USER/PATH, the later file winning (systemd.exec(5)).
    serviceConfig = {
      EnvironmentFile = [bootEnv "-${userEnv}"];
      # Plugin children of the old user, like librespot holding its port, die with the loader.
      KillMode = lib.mkForce "mixed";
    };
    preStart = ''
      ${lib.getExe migrateSharedData} ${cfg.stateDir} ${dataDir cfg.user} \
        || echo "decky: some shared plugin data did not move; Decky starts with what did" >&2
    '';
    environment = {
      # Plugins and loader.json stay shared and declared; only plugin data follows the user.
      PRIVILEGED_PATH = cfg.stateDir;
      # A plugin subprocess may get a narrower PATH than extraPackages gives the loader.
      GAMESCOPE_SET_DISPLAY = lib.getExe config.gaming.gamescopeSession.displayTool;
      # Bare hostname the LAN's DNS already answers for; set networking.domain to advertise an FQDN instead.
      DECKIFY_ADVERTISED_HOST = config.networking.fqdnOrHostName;
      # One household Spotify app; its dashboard lists https://<host>:39281/callback for each host.
      DECKIFY_SPOTIFY_CLIENT_ID = "5495bd441a014dbc8ea6391baf1d670b";
      # librespot's Spotify Connect discovery server, otherwise on a random port the firewall drops.
      DECKIFY_ZEROCONF_PORT = "39283";
    };
  };

  security.pam.services = lib.mkMerge [
    (lib.mkIf config.services.displayManager.sddm.enable {
      sddm.rules.session.decky-follow-user = followUserRule;
      sddm-autologin.rules.session.decky-follow-user = followUserRule;
    })
    (lib.mkIf config.services.greetd.enable {
      greetd.rules.session.decky-follow-user = followUserRule;
    })
  ];

  systemd.tmpfiles.rules = lib.concatMap dataDirRules config.hostSpec.users;

  # Deckify's Spotify login page (its QR code) and librespot's Spotify Connect discovery, reachable from phones.
  networking.firewall.allowedTCPPorts = [39281 39283];

  # decky-loader's frontend builds with pnpm (build-time only, not runtime).
  nixpkgs.config.permittedInsecurePackages = ["pnpm-9.15.9"];
}
