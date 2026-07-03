{
  plugins.harpoon = {
    enable = true;
    enableTelescope = false;
  };

  # LazyVim harpoon2 keybinds: <leader>H add, <leader>h menu, <leader>1-5 jump.
  keymaps =
    [
      {
        mode = "n";
        key = "<leader>H";
        action.__raw = "function() require('harpoon'):list():add() end";
        options.desc = "Harpoon File";
      }
      {
        mode = "n";
        key = "<leader>h";
        action.__raw = "function() local h = require('harpoon') h.ui:toggle_quick_menu(h:list()) end";
        options.desc = "Harpoon Quick Menu";
      }
    ]
    ++ map (n: {
      mode = "n";
      key = "<leader>${toString n}";
      action.__raw = "function() require('harpoon'):list():select(${toString n}) end";
      options.desc = "Harpoon to File ${toString n}";
    }) [1 2 3 4 5];
}
