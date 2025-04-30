{
  config,
  pkgs,
  ...
}: {
  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-backgroundremoval
      obs-pipewire-audio-capture
      obs-command-source
    ];
  };

  security.polkit.enable = true;
  boot.extraModulePackages = with config.boot.kernelPackages; [v4l2loopback];

  # Load v4l2loopback module at boot
  boot.kernelModules = ["v4l2loopback"];

  # Configure the module
  boot.extraModprobeConfig = ''
    options v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
  '';

  # Create persistent device
  services.udev.extraRules = ''
    KERNEL=="video[0-9]*", ATTR{name}=="OBS Cam", TAG+="systemd", ENV{SYSTEMD_WANTS}="v4l2loopback-device.service"
  '';

  # Service to ensure device exists
  systemd.services.v4l2loopback-device = {
    description = "Create v4l2loopback device for OBS";
    wantedBy = ["multi-user.target"];
    after = ["systemd-modules-load.service"];
    script = ''
      if ! test -c /dev/video1; then
        ${pkgs.kmod}/bin/modprobe v4l2loopback devices=1 video_nr=1 card_label="OBS Cam" exclusive_caps=1
      fi
    '';
  };
}
