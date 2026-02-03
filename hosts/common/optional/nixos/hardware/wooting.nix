{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    wootility
  ];

  hardware.wooting.enable = true;
}
