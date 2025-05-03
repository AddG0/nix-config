{
  pkgs,
  config,
  ...
}: {
  environment.systemPackages = with pkgs; [
    polychromatic
  ];

  hardware.openrazer = {
    enable = true;
    users = [config.hostSpec.username];
  };
}
