# Defaults for headless servers; each part gates itself on hostSpec.hostType.
{lib, ...}: {
  imports = lib.custom.scanPaths ./.;
}
