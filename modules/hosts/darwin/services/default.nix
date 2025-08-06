# Add your reusable Darwin system service modules to this directory.
# These are modules you would share with others, not your personal configurations.
{lib, ...}: {
  imports = lib.custom.scanPaths ./.;
}
