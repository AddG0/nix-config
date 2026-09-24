{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.stylix.fonts) monospace sansSerif;

  slackCss = ''
    * { font-family: "${sansSerif.name}" !important; }
    code, pre, kbd, samp, tt { font-family: "${monospace.name}", monospace !important; }
  '';

  # Slack bundles Lato as a webfont, so fontconfig can't reach it — only a
  # user-origin stylesheet outranks its author `!important` rules.
  slackFontPreload = pkgs.writeText "slack-stylix-fonts.js" ''

    require("electron").webFrame.insertCSS(${builtins.toJSON slackCss}, {cssOrigin: "user"});
  '';

  slackFixed = pkgs.slack.overrideAttrs (oldAttrs: {
    nativeBuildInputs = oldAttrs.nativeBuildInputs ++ [pkgs.asar];
    postInstall =
      (oldAttrs.postInstall or "")
      + ''
        # KDE Wayland matches the desktop file by name, which must be "Slack.desktop"
        mv $out/share/applications/{slack,Slack}.desktop

        asar extract $out/lib/slack/resources/app.asar slack-app
        cat ${slackFontPreload} >> slack-app/dist/preload.bundle.js
        asar pack slack-app $out/lib/slack/resources/app.asar --unpack "*.node"
      '';
  });
in {
  home.packages =
    [(pkgs.discord.override {withVencord = true;})]
    # On Darwin, Slack is managed via homebrew cask for stable path (avoids
    # SMAppService re-registration popups on every nix store path change)
    ++ lib.optional pkgs.stdenv.hostPlatform.isLinux slackFixed;

  # Vencord applies QuickCSS by default, so this needs no settings.json entry.
  xdg.configFile."Vencord/settings/quickCss.css".text = ''
    :root {
      --font-primary: "${sansSerif.name}";
      --font-display: "${sansSerif.name}";
      --font-code: "${monospace.name}";
    }
  '';

  # Vencord rewrites settings.json itself, so merge the key in rather than own the file.
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
        'reduce $p[] as $n (.; .plugins[$n].enabled = true)' > "$tmp"
      run mkdir -p "$(dirname "$f")"
      run mv "$tmp" "$f"
    '';
}
