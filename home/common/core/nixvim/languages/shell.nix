{pkgs, ...}: {
  programs.nixvim = {
    plugins.lsp.servers.bashls.enable = true;
    plugins.conform-nvim.settings.formatters_by_ft.sh = ["shfmt"];
    # shellcheck is pulled in by lint's autoInstall (../lsp.nix).
    plugins.lint.lintersByFt = {
      sh = ["shellcheck"];
      bash = ["shellcheck"];
    };
    extraPackages = [pkgs.shfmt];
  };
}
