{lib, ...}: {
  imports = [
    (with lib.custom.optional.home; [browsers.zen.core comms.discord])
  ];
}
