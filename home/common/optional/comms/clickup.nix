{
  pkgs,
  lib,
  ...
}: {
  assertions = [(lib.hm.assertions.assertPlatform "tools.clickup" pkgs lib.platforms.linux)];
  home.packages = [pkgs.clickup];
}
