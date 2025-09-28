{
  config,
  lib,
  ...
}: {
  options = {
    nixvim-config.plugins.nvim-colorizer.enable = lib.mkEnableOption "enables nvim-colorizer module";
  };

  config = lib.mkIf config.nixvim-config.plugins.nvim-colorizer.enable {
    programs.nixvim.plugins = {
      colorizer = {
        enable = true;
        settings.fileTypes = ["*"];
      };
    };
  };
}
