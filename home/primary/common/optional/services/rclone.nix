{config, ...}: let
  homeDir = config.home.homeDirectory;

  commonOptions = {
    vfs-cache-max-age = "24h";
    vfs-read-chunk-size = "64M";
    buffer-size = "32M";
  };

  driveOptions =
    commonOptions
    // {
      drive-export-formats = "docx,xlsx,pptx";
    };
in {
  # Mounts only - config is managed by rclone itself
  # Run `just setup-rclone` to configure new remotes
  services.rcloneMounts = {
    enable = true;
    remotes = {
      AddG.mounts."" = {
        mountPoint = "${homeDir}/cloud/AddG";
        options = driveOptions;
      };
      # Work.mounts."" = {
      #   mountPoint = "${homeDir}/cloud/Work";
      #   options = driveOptions;
      # };
      # Dropbox.mounts."" = {
      #   mountPoint = "${homeDir}/cloud/Dropbox";
      #   options = commonOptions;
      # };
    };
  };
}
