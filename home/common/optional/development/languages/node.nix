{
  config,
  pkgs,
  inputs,
  lib,
  ...
}: {
  programs.git.ignores = lib.custom.gitignoreFromTemplates inputs.github-gitignore-templates ["Node"];

  home.packages = with pkgs; [
    pnpm
    bun
    yarn-berry
    yarn-berry-completions
    typescript
  ];

  # Node 17+ verbatim DNS binds dev servers ::1-only here; Firefox/Zen can't reach those.
  home.sessionVariables.NODE_OPTIONS = "--dns-result-order=ipv4first";

  programs.npm = {
    enable = true;
    package = pkgs.nodejs_24;
    settings.update-notifier = false;
  };

  # bun reads $XDG_CONFIG_HOME/.npmrc only — no ~/.npmrc or NPM_CONFIG_USERCONFIG fallback.
  # Leading slash in the key is upstream's removePrefix quirk, not a typo.
  xdg.configFile.".npmrc".source = config.home.file."/.config/npm/npmrc".source;

  # Berry-mode yarn aliases (mirrors oh-my-zsh's yarn plugin, berry=yes). The omz
  # yarn plugin is intentionally omitted: its bundled `_yarn` is yarn-v1-shaped
  # and would collide on fpath with the Berry-accurate `_yarn` from the
  # yarn-berry-completions package. Defining the aliases here keeps them without that clash.
  programs.zsh.shellAliases = {
    y = "yarn";
    ya = "yarn add";
    yad = "yarn add --dev";
    yap = "yarn add --peer";
    yb = "yarn build";
    ycc = "yarn cache clean";
    yd = "yarn dev";
    ydlx = "yarn dlx";
    yf = "yarn format";
    yh = "yarn help";
    yi = "yarn init";
    yii = "yarn install --immutable";
    yifl = "yarn install --immutable";
    yin = "yarn install";
    yln = "yarn lint";
    ylnf = "yarn lint --fix";
    yn = "yarn node";
    yp = "yarn pack";
    yrm = "yarn remove";
    yrun = "yarn run";
    ys = "yarn serve";
    yst = "yarn start";
    yt = "yarn test";
    ytc = "yarn test --coverage";
    yui = "yarn upgrade-interactive";
    yup = "yarn upgrade";
    yv = "yarn version";
    yw = "yarn workspace";
    yws = "yarn workspaces";
    yy = "yarn why";
  };

  programs.zsh.oh-my-zsh.plugins = [
    "node"
    "npm"
  ];
}
