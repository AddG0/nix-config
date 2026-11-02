# SDDM with the SilentSDDM theme, as a host's login manager in place of greetd.
{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.display) monitors;
  kwinOutputs = import ./_kwin-outputs.nix {inherit lib pkgs;} monitors;
  # The bundled smoky.jpg is 1920x1080, so a 32:9 panel crops it to 1920x540 and upscales.
  wallpaper = lib.custom.relativeToRoot "assets/wallpapers/mist-winter-trees.jpg";
in {
  imports = [
    inputs.silent-sddm.nixosModules.default
    (import ./_retain-splash.nix {})
  ];

  assertions = [
    {
      assertion = !config.services.greetd.enable;
      message = "silent-sddm: greetd is enabled too, and both would claim the display; drop the greetd import on this host.";
    }
  ];

  programs.silentSDDM = {
    enable = true;
    theme = lib.mkDefault "default";
    backgrounds.wallpaper = wallpaper;
    settings = {
      LoginScreen.background = baseNameOf wallpaper;
      LockScreen.background = baseNameOf wallpaper;
    };
  };

  # Rewritten every boot, so "Apply Plasma Settings" in the SDDM KCM lasts one boot only.
  systemd.services.sddm-kwin-outputs = lib.mkIf (monitors != [] && config.services.displayManager.sddm.wayland.compositor == "kwin") {
    description = "Monitor layout for SDDM's KWin greeter, from display.monitors";
    wantedBy = ["display-manager.service"];
    before = ["display-manager.service"];
    after = ["systemd-udev-trigger.service" "systemd-modules-load.service"];
    serviceConfig = {
      Type = "oneshot";
      User = "sddm";
      Group = "sddm";
      ExecStart = "${lib.getExe kwinOutputs} /sys/class/drm ${config.users.users.sddm.home}/.config/kwinoutputconfig.json";
    };
  };
}
