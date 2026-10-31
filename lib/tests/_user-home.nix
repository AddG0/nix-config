{lib, ...}: {
  imports = [
    (with lib.custom.optional.home; [browsers comms])
  ];
}
