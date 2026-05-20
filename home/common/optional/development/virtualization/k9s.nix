{pkgs, ...}: {
  programs = {
    k9s = {
      enable = true;
      # https://k9scli.io/topics/aliases/
      # aliases = {};
      settings = {
        skin = "catppuccino-mocha";
      };
      # Replace 'base: &base "#1e1e2e"' with 'base: &base "default"' to make
      # fg/bg transparent. Result is passed as a path so HM symlinks the YAML
      # directly — no eval-time readFile, no IFD.
      skins.catppuccin-mocha = toString (pkgs.runCommand "catppuccin-mocha.yaml" {} ''
        sed -E 's@(base: &base ).+@\1 "default"@g' \
          "${pkgs.themes.catppuccin.k9s}/dist/catppuccin-mocha.yaml" > $out
      '');
    };
  };
}
