{lib, ...}: {
  imports = lib.flatten [
    (with lib.custom.optional.home.gaming; [minecraft])
  ];
}
