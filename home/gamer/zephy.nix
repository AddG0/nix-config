{lib, ...}: {
  imports = lib.flatten [
    (with lib.custom.optional.home; [browsers])
    (with lib.custom.optional.home.gaming; [heroic minecraft])
  ];

  desktops.defaultSession = "plasma";
}
