_: {
  programs.nixvim = {
    plugins = {
      telescope.enable = true;
      oil.enable = true;
      neo-tree.enable = true;
    };

    keymaps = [
      {
        key = "<leader>e";
        action = "<cmd>Neotree toggle<cr>";
        options.desc = "Toggle file tree";
      }
      {
        key = "<leader>ff";
        action = "<cmd>Telescope find_files<cr>";
        options.desc = "Find files";
      }
      {
        key = "<leader>fg";
        action = "<cmd>Telescope live_grep<cr>";
        options.desc = "Live grep";
      }
      {
        key = "<leader>fb";
        action = "<cmd>Telescope buffers<cr>";
        options.desc = "Buffers";
      }
      {
        key = "-";
        action = "<cmd>Oil<cr>";
        options.desc = "Open parent directory";
      }
    ];
  };
}
