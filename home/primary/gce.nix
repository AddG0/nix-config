{lib, ...}: {
  imports = lib.flatten [
    (with lib.custom.optional.home; [helper-scripts])
    (with lib.custom.optional.home.development; [gcloud virtualization.kubernetes])
  ];
}
