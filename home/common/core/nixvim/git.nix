_: {
  programs.nixvim = {
    plugins = {
      gitsigns.enable = true;
      diffview.enable = true;
      neogit.enable = true;
    };
    keymaps = [
      {
        mode = "n";
        key = "<leader>gg";
        action = "<cmd>Neogit<CR>";
      }
    ];
  };
}
