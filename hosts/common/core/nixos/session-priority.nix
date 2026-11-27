# On desktops and laptops the compositor's session.slice outweighs apps under CPU contention, so the desktop never waits behind a build.
{
  config,
  lib,
  ...
}: {
  # systemd ships 100; Hyprland, the terminal and audio live here.
  systemd.user.slices.session = lib.mkIf (config.hostSpec.hostType != "server") {
    sliceConfig.CPUWeight = 1000;
  };
}
