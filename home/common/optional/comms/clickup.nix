{
  config,
  pkgs,
  lib,
  ...
}: {
  assertions = [(lib.hm.assertions.assertPlatform "tools.clickup" pkgs lib.platforms.linux)];
  home.packages = [pkgs.clickup];

  programs.code-assistant-profiles = {
    addons.clickup.mcpServers.clickup = {
      type = "remote";
      url = "https://mcp.clickup.com/mcp";
    };
    profiles.default.include = [config.programs.code-assistant-profiles.addons.clickup];
  };
}
