{
  inputs,
  config,
  pkgs,
  ...
}: {
  imports = [inputs.jovian.nixosModules.default];

  jovian.decky-loader = {
    enable = true;
    # Run as the logged-in user so plugins reach their session — Deckcord's voice
    # backend hardcodes /run/user/1000 (dbus/pipewire). Plugins run as you.
    user = config.hostSpec.primaryUsername;
    extraPackages = [pkgs.systemd]; # decky shells out to `systemctl`
    extraPythonPackages = ps: [ps.aiohttp-cors]; # Deckcord backend imports it
    # Silence the "plugin update available" notification (loader.json).
    settings.notificationSettings.pluginUpdates = false;
    # Keys are the store's own folder names, so a UI install wouldn't duplicate.
    plugins = {
      Deckcord = pkgs.decky.deckcord;
      decky-steamgriddb = pkgs.decky.steamgriddb;
      protondb-decky = pkgs.decky.protondb-badges;
      TabMaster = pkgs.decky.tabmaster;
      hltb-for-deck = pkgs.decky.hltb;
      SDH-CssLoader = pkgs.decky.css-loader;
    };
  };
  # decky-loader's frontend builds with pnpm (build-time only, not runtime).
  nixpkgs.config.permittedInsecurePackages = ["pnpm-9.15.9"];

  # Steam's CEF debugger was moved 8080 -> 21379 (gaming/steam.nix; 8080 is
  # commonly used, leave it free). Patch Decky to connect on the new port.
  nixpkgs.overlays = [
    (_: prev: {
      decky-loader = prev.decky-loader.overrideAttrs (old: {
        postFixup =
          (old.postFixup or "")
          + ''
            for site in $out/lib/python*/site-packages/decky_loader; do
              substituteInPlace "$site/injector.py" \
                --replace-fail "http://localhost:8080" "http://localhost:21379"
              substituteInPlace "$site/localplatform/localplatformlinux.py" \
                --replace-fail "-iTCP:8080" "-iTCP:21379"
            done
            # drop stale bytecode so the edits take effect at runtime
            find "$out" -name __pycache__ -type d -exec rm -rf {} + 2>/dev/null || true
          '';
      });
    })
  ];
}
