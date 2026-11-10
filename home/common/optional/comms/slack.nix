{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.stylix.fonts) monospace sansSerif;
  inherit (config.lib.stylix) colors;
  c = colors.withHashtag;
  rgb = n: "${colors."${n}-rgb-r"},${colors."${n}-rgb-g"},${colors."${n}-rgb-b"}";
  recolor = import ./_recolor.nix {inherit lib colors;};

  # Slack's colour tokens (sk_* take bare "r,g,b" triplets); mapped from its dark theme.
  slackColors = {
    "TextyTheme-wysiwyg-border-color" = c.base03;
    "TextyTheme-send-bg" = c.base0B;
    "TextyTheme-send-bg-hover" = c.base0C;
    "TextyTheme-send-fg" = c.base00;
    "sk_foreground_max" = rgb "base05";
    "sk_foreground_high" = rgb "base05";
    "sk_foreground_mid" = rgb "base05";
    "sk_foreground_low" = rgb "base05";
    "sk_foreground_soft" = rgb "base05";
    "sk_foreground_min" = rgb "base05";
    "sk_foreground_max_solid" = rgb "base05";
    "sk_foreground_high_solid" = rgb "base04";
    "sk_foreground_mid_solid" = rgb "base04";
    "sk_foreground_low_solid" = rgb "base03";
    "sk_foreground_soft_solid" = rgb "base02";
    "sk_foreground_min_solid" = rgb "base02";
    "sk_primary_background" = rgb "base00";
    "sk_primary_foreground" = rgb "base05";
    "sk_inverted_background" = rgb "base05";
    "sk_inverted_foreground" = rgb "base00";
    "sk_highlight" = rgb "base0D";
    "sk_highlight_accent" = rgb "base0D";
    "sk_highlight_hover" = rgb "base07";
    "dt_color-base-pry" = c.base00;
    "dt_color-base-sec" = c.base00;
    "dt_color-base-ter" = c.base01;
    "dt_color-base-inv-pry" = c.base02;
    "dt_color-content-pry" = c.base05;
    "dt_color-content-sec" = "${c.base05}cc";
    "dt_color-content-ter" = "${c.base05}99";
    "dt_color-content-hgl-1" = c.base0D;
    "dt_color-content-hgl-2" = c.base0B;
    "dt_color-content-hgl-3" = c.base0A;
    "dt_color-content-imp" = c.base08;
    "dt_color-otl-pry" = c.base03;
    "dt_color-otl-sec" = c.base02;
    "dt_color-otl-ter" = c.base01;
    "dt_color-theme-base-pry" = c.base0D;
    "dt_color-theme-base-sec" = c.base02;
    "dt_color-theme-base-inv-pry" = c.base01;
    "dt_color-theme-base-inv-sec" = c.base02;
    "dt_color-theme-base-hgl-1" = c.base0D;
    "dt_color-theme-content-pry" = c.base05;
    "dt_color-theme-content-sec" = "${c.base05}cc";
    "dt_color-theme-content-ter" = c.base00;
    "dt_color-theme-content-hgl-1" = c.base00;
    "dt_color-theme-content-inv-pry" = c.base05;
    "dt_color-theme-content-inv-sec" = "${c.base05}cc";
    "dt_color-theme-content-inv-ter" = "${c.base05}99";
    "dt_color-theme-surf-pry" = "${c.base02}80";
    "dt_color-theme-surf-sec" = "${c.base02}80";
    "dt_color-theme-surf-ter" = c.base01;
    "dt_color-theme-surf-inv-pry" = "${c.base02}80";
    "dt_color-theme-surf-inv-sec" = c.base01;
    "dt_color-theme-surf-inv-ter" = "${c.base02}80";
    "dt_color-theme-otl-pry" = c.base02;
    "dt_color-theme-otl-inv-pry" = c.base02;
    # Boot skeleton tokens, set inline from the workspace's cached theme before the client loads.
    "dt_color-plt-bootPrimary-5" = rgb "base00";
    "dt_color-plt-bootHighlight1-0" = rgb "base01";
  };

  slackCss = ''
    * { font-family: "${sansSerif.name}" !important; }
    code, pre, kbd, samp, tt { font-family: "${monospace.name}", monospace !important; }
    * {
    ${lib.concatStrings (lib.mapAttrsToList (k: v: "  --${k}: ${v} !important;\n") slackColors)}}
    .p-theme_background { background: ${c.base00} !important; }
    /* The boot skeleton's sidebar is an inline literal, which recolor.js never sees. */
    .p-client_container_placeholder--sidebar { background-color: ${c.base01} !important; }
  '';

  # Slack ships its own webfont and palette; only a user-origin sheet outranks its `!important` rules.
  slackThemePreload = pkgs.writeText "slack-stylix-theme.js" ''

    {
      const {webFrame} = require("electron");
      webFrame.insertCSS(${builtins.toJSON slackCss}, {cssOrigin: "user"});
      let key;
      ${recolor} (css) => {
        if (key) webFrame.removeInsertedCSS(key);
        key = webFrame.insertCSS(css);
      });
    }
  '';

  slackFixed = pkgs.slack.overrideAttrs (oldAttrs: {
    nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [pkgs.asar pkgs.nodejs];
    postInstall =
      (oldAttrs.postInstall or "")
      + ''
        # KDE Wayland matches the desktop file by name, which must be "Slack.desktop"
        mv $out/share/applications/{slack,Slack}.desktop

        asar extract $out/lib/slack/resources/app.asar slack-app
        cat ${slackThemePreload} >> slack-app/dist/preload.bundle.js
        # A syntax error here only shows at runtime, as a renderer crash loop.
        node --check slack-app/dist/preload.bundle.js
        asar pack slack-app $out/lib/slack/resources/app.asar --unpack "*.node"
      '';
  });
in {
  # On Darwin, Slack is a homebrew cask: it needs a stable path for SMAppService.
  home.packages = lib.optionals pkgs.stdenv.hostPlatform.isLinux [slackFixed];
}
