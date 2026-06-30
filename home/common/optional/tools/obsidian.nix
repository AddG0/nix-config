{
  config,
  inputs,
  ...
}: {
  programs.obsidian = {
    enable = true;

    vaults.notes = {
      target = "home/notes";

      settings = {
        app = {
          vimMode = true;
        };

        appearance = {
          theme = "obsidian";
        };

        hotkeys = {
          "editor:swap-line-up" = [
            {
              modifiers = ["Alt"];
              key = "ArrowUp";
            }
          ];
          "editor:swap-line-down" = [
            {
              modifiers = ["Alt"];
              key = "ArrowDown";
            }
          ];
        };

        themes = [
          inputs.catppuccin-obsidian
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
