{
  inputs,
  pkgs,
  ...
}: {
  imports = [inputs.jovian.nixosModules.default];

  jovian.decky-loader = {
    enable = true;
    extraPackages = [pkgs.systemd]; # decky shells out to `systemctl`
    extraPythonPackages = ps: [ps.aiohttp-cors]; # Deckcord backend imports it
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
}
