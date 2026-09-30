{
  pkgs,
  customPkgs,
  ...
}: {
  home.packages = [customPkgs.bootdev-cli];
}
