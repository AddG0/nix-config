{
  config,
  pkgs,
  ...
}: {
  programs.obsidian = {
    enable = true;

    vaults.notes = {
      target = "home/notes";

      settings = {
        appearance = {
          theme = "obsidian";
        };

        themes = [
          pkgs.themes.catppuccin.obsidian
        ];

        cssSnippets = [
          {
            name = "theme-font-override";
            text = ''
              body {
                --font-text-theme: "${config.stylix.fonts.serif.name}", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                --font-interface-theme: "${config.stylix.fonts.sansSerif.name}", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                --font-monospace-theme: "${config.stylix.fonts.monospace.name}", ui-monospace, monospace;
              }
            '';
          }
        ];
      };
    };
  };
}
