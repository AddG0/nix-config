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
  };

  slackCss = ''
    * { font-family: "${sansSerif.name}" !important; }
    code, pre, kbd, samp, tt { font-family: "${monospace.name}", monospace !important; }
    * {
    ${lib.concatStrings (lib.mapAttrsToList (k: v: "  --${k}: ${v} !important;\n") slackColors)}}
    .p-theme_background { background: ${c.base00} !important; }
    .c-button--primary, .c-button--danger { color: ${c.base00} !important; }
  '';

  # Slack ships its own webfont and palette; only a user-origin sheet outranks its `!important` rules.
  # Called as `${recolor} (css) => { …apply css… });`.
  recolor = "(${builtins.readFile ./recolor.js})(${builtins.toJSON (lib.genAttrs (map (n: "base0${n}") ["0" "1" "2" "3" "4" "5" "8" "9" "A" "B" "C" "D" "E"]) (n: c.${n}))},";

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
    nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [pkgs.asar];
    postInstall =
      (oldAttrs.postInstall or "")
      + ''
        # KDE Wayland matches the desktop file by name, which must be "Slack.desktop"
        mv $out/share/applications/{slack,Slack}.desktop

        asar extract $out/lib/slack/resources/app.asar slack-app
        cat ${slackThemePreload} >> slack-app/dist/preload.bundle.js
        asar pack slack-app $out/lib/slack/resources/app.asar --unpack "*.node"
      '';
  });

  # Discord's current semantic tokens, which Stylix's Vencord theme predates.
  discordColors = let
    a = base: alpha: "${c.${base}}${alpha}";
    shade = pct: "color-mix(in srgb, ${c.base0D} ${toString pct}%, ${c.base00})";
    brandRamp = lib.listToAttrs (map (n: {
      name = "brand-${toString n}";
      value =
        if n <= 345
        then c.base07
        else if n <= 500
        then c.base0D
        else shade (100 - (n - 500) / 5);
    }) [100 130 160 200 230 260 300 330 345 360 400 430 460 500 530 560 600 630 660 700 730 760 800 830 860 900]);
    brandAlphas = lib.listToAttrs (map (n: {
      name = "brand-${toString n}a";
      value = "color-mix(in srgb, ${c.base0D} ${toString n}%, transparent)";
    }) [5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95]);
  in
    brandRamp
    // brandAlphas
    // {
      "blurple-50" = c.base0D;
      "white" = c.base05;
      "background-brand" = c.base0D;
      "text-default" = c.base05;
      "text-strong" = c.base05;
      "text-subtle" = a "base05" "cc";
      "text-invert" = c.base00;
      "text-overlay-dark" = c.base00;
      "text-overlay-light" = c.base05;
      "text-feedback-critical" = c.base08;
      "text-feedback-info" = c.base0D;
      "text-status-dnd" = c.base08;
      "text-status-idle" = c.base0A;
      "text-status-offline" = a "base05" "99";
      "text-status-online" = c.base0B;
      "text-voice-connected" = c.base0B;
      "text-voice-disconnected" = c.base08;
      "text-voice-speaking" = c.base0B;
      "text-code" = c.base05;
      "icon-default" = c.base05;
      "icon-strong" = c.base05;
      "icon-subtle" = a "base05" "cc";
      "icon-muted" = a "base05" "99";
      "icon-brand" = c.base0D;
      "icon-link" = c.base0D;
      "icon-invert" = c.base00;
      "icon-overlay-dark" = c.base00;
      "icon-overlay-light" = c.base05;
      "icon-feedback-critical" = c.base08;
      "icon-feedback-info" = c.base0D;
      "icon-feedback-notification" = c.base08;
      "icon-feedback-positive" = c.base0B;
      "icon-feedback-warning" = c.base0A;
      "icon-status-dnd" = c.base08;
      "icon-status-idle" = c.base0A;
      "icon-status-offline" = a "base05" "99";
      "icon-status-online" = c.base0B;
      "icon-voice-connected" = c.base0B;
      "icon-voice-disconnected" = c.base08;
      "icon-voice-muted" = c.base08;
      "icon-voice-speaking" = c.base0B;
      "interactive-text-default" = a "base05" "cc";
      "interactive-text-hover" = c.base05;
      "interactive-text-active" = c.base05;
      "interactive-icon-default" = a "base05" "cc";
      "interactive-icon-hover" = c.base05;
      "interactive-icon-active" = c.base05;
      "interactive-background-default" = a "base02" "80";
      "interactive-background-hover" = c.base02;
      "interactive-background-active" = c.base03;
      "interactive-background-selected" = c.base03;
      "interactive-accent-background-default" = a "base0D" "33";
      "interactive-accent-background-hover" = a "base0D" "66";
      "interactive-accent-background-active" = a "base0D" "99";
      "interactive-accent-background-selected" = a "base0D" "66";
      "background-mod-muted" = a "base02" "80";
      "background-mod-normal" = c.base02;
      "background-mod-strong" = c.base03;
      "background-scrim" = a "base01" "b8";
      "background-scrim-lightbox" = a "base01" "eb";
      "background-feedback-critical" = a "base08" "14";
      "background-feedback-info" = a "base0D" "14";
      "background-feedback-notification" = c.base08;
      "background-feedback-positive" = a "base0B" "14";
      "background-feedback-warning" = a "base0A" "14";
      "background-code-addition" = a "base0B" "1f";
      "background-code-deletion" = a "base08" "1f";
      "background-voice-muted" = a "base08" "1f";
      "border-muted" = c.base02;
      "border-subtle" = c.base02;
      "border-normal" = c.base03;
      "border-strong" = c.base04;
      "border-focus" = c.base0D;
      "border-feedback-critical" = c.base08;
      "border-feedback-info" = c.base0D;
      "border-feedback-positive" = c.base0B;
      "border-feedback-warning" = c.base0A;
      "border-voice-muted" = a "base08" "1f";
      "control-primary-background-default" = c.base0D;
      "control-primary-background-hover" = c.base07;
      "control-primary-background-active" = c.base07;
      "control-primary-border-default" = c.base0D;
      "control-primary-border-hover" = c.base07;
      "control-primary-border-active" = c.base07;
      "control-primary-text-default" = c.base00;
      "control-primary-text-hover" = c.base00;
      "control-primary-text-active" = c.base00;
      "control-primary-icon-default" = c.base00;
      "control-primary-icon-hover" = c.base00;
      "control-primary-icon-active" = c.base00;
      "control-secondary-background-default" = c.base02;
      "control-secondary-background-hover" = c.base03;
      "control-secondary-background-active" = c.base03;
      "control-secondary-border-default" = c.base02;
      "control-secondary-border-hover" = c.base03;
      "control-secondary-border-active" = c.base03;
      "control-secondary-text-default" = c.base05;
      "control-secondary-text-hover" = c.base05;
      "control-secondary-text-active" = c.base05;
      "control-secondary-icon-default" = c.base05;
      "control-secondary-icon-hover" = c.base05;
      "control-secondary-icon-active" = c.base05;
      "control-icon-only-background-hover" = c.base02;
      "control-icon-only-background-active" = c.base03;
      "control-icon-only-border-hover" = "transparent";
      "control-icon-only-border-active" = "transparent";
      "control-icon-only-icon-default" = a "base05" "cc";
      "control-icon-only-icon-hover" = c.base05;
      "control-icon-only-icon-active" = c.base05;
      "input-background-default" = c.base01;
      "input-background-error-default" = a "base08" "14";
      "input-border-default" = c.base02;
      "input-border-hover" = c.base03;
      "input-border-active" = c.base0D;
      "input-border-error-default" = c.base08;
      "card-background-default" = c.base01;
      "card-border-default" = c.base02;
      "card-primary-pressed-bg" = c.base02;
      "card-secondary-bg" = c.base02;
      "card-secondary-pressed-bg" = c.base03;
      "chat-background" = c.base00;
      "chat-border" = c.base02;
      "chat-text-muted" = a "base05" "99";
      "button-danger-background-disabled" = a "base08" "80";
      "scrollbar-auto-scrollbar-color-thumb" = c.base02;
      "scrollbar-auto-scrollbar-color-track" = "transparent";
    };
  # Vencord's renderer.js runs in Discord's page, so the recolour rides along at its end.
  vencordRecolored = pkgs.runCommand "vencord-recolored" {} ''
    cp -r ${pkgs.vencord} $out
    chmod u+w $out/renderer.js
    cat >> $out/renderer.js <<'EOF'

    {
      const el = document.createElement("style");
      el.id = "nix-recolor";
      const attach = () => document.head.prepend(el);
      document.head ? attach() : addEventListener("DOMContentLoaded", attach);
      ${recolor} (css) => { el.textContent = css; });
    }
    EOF
  '';
in {
  home.packages =
    [
      (pkgs.discord.override {
        withVencord = true;
        vencord = vencordRecolored;
      })
    ]
    # On Darwin, Slack is managed via homebrew cask for stable path (avoids
    # SMAppService re-registration popups on every nix store path change)
    ++ lib.optional pkgs.stdenv.hostPlatform.isLinux slackFixed;

  # Stylix's Vencord theme reads fonts from an unset `--font`; its own selectors must be matched to override it.
  xdg.configFile."Vencord/settings/quickCss.css".text = ''
    :root { --font: "${sansSerif.name}"; }
    .theme-light, .theme-dark, .theme-darker, .theme-midnight, .visual-refresh {
    ${lib.concatStrings (lib.mapAttrsToList (k: v: "  --${k}: ${v} !important;\n") discordColors)}}
  '';

  # Vencord rewrites settings.json itself, so merge keys in rather than own the file.
  home.activation.vencordPlugins = let
    plugins = [
      "VolumeBooster"
      "ShikiCodeblocks"
      "UserVoiceShow"
      "MessageLogger"
      "ClearURLs"
      "CallTimer"
      "PlatformIndicators"
      "ViewRaw"
      "ImageZoom"
      "FixYoutubeEmbeds"
      "NoReplyMention"
    ];
  in
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      f="${config.xdg.configHome}/Vencord/settings/settings.json"
      tmp=$(mktemp)
      { [ -f "$f" ] && cat "$f" || echo '{}'; } | ${lib.getExe pkgs.jq} --argjson p '${builtins.toJSON plugins}' \
        'reduce $p[] as $n (.; .plugins[$n].enabled = true)
          | .enabledThemes = ((.enabledThemes // []) + ["stylix.theme.css"] | unique)' > "$tmp"
      run mkdir -p "$(dirname "$f")"
      run mv "$tmp" "$f"
    '';
}
