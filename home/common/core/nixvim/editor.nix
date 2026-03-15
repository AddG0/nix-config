_: {
  programs.nixvim.plugins = {
    treesitter.enable = true;
    mini = {
      enable = true;
      modules.icons = {};
      mockDevIcons = true;
    };
    conform-nvim.enable = true;
    toggleterm = {
      enable = true;
      settings = {
        direction = "horizontal";
        open_mapping = "[[<C-\\>]]";
      };
    };
    flash.enable = true;
    render-markdown.enable = true;
  };
}
