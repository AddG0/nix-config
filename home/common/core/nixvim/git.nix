_: {
  programs.nixvim = {
    # Show full file in diffs instead of just changed hunks
    opts.diffopt = "internal,filler,closeoff,context:99999";
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
