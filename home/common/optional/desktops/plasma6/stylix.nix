# Stylix for Plasma through plasma-manager: its kde target's XDG_CONFIG_DIRS defaults never reach the session.
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (config.stylix) fonts;
  font = family: pointSize: {inherit family pointSize;};
in
  lib.mkIf config.stylix.enable {
    programs.plasma = {
      # Same mapping as stylix's own kdeglobals: applications size for text, desktop size for chrome.
      fonts = {
        general = font fonts.sansSerif.name fonts.sizes.applications;
        fixedWidth = font fonts.monospace.name fonts.sizes.terminal;
        small = font fonts.sansSerif.name fonts.sizes.desktop;
        toolbar = font fonts.sansSerif.name fonts.sizes.desktop;
        menu = font fonts.sansSerif.name fonts.sizes.desktop;
        windowTitle = font fonts.sansSerif.name fonts.sizes.desktop;
      };

      workspace = {
        iconTheme = lib.mkIf config.stylix.icons.enable (
          if config.stylix.polarity == "light"
          then config.stylix.icons.light
          else config.stylix.icons.dark
        );
        # Plasma's gtkconfig serves this to X11 apps (Spotify) in every session.
        cursor = lib.mkIf (config.stylix.cursor != null) {
          theme = config.stylix.cursor.name;
          inherit (config.stylix.cursor) size;
        };
      };
    };

    # Stylix's own switch for this (kded 6 still reads kded5rc) never reaches the session; left on, gtkconfig overwrites gtkrc and serves Plasma's scale to X11 apps.
    programs.plasma.configFile.kded5rc.Module-gtkconfig.autoload = false;

    # OnlyShowIn=KDE for stylix's store-built autostart entry: plasma-apply-lookandfeel sets Plasma's Xft.dpi in other sessions too.
    xdg.configFile."systemd/user/app-stylix\\x2dactivate\\x2dkde@autostart.service.d/only-kde.conf".text = ''
      [Service]
      ExecCondition=${pkgs.systemd}/lib/systemd/systemd-xdg-autostart-condition "KDE" ""
    '';

    # Same for its switch-time run, which inherits the session's DISPLAY.
    home.activation = {
      stylixHideDisplay = lib.hm.dag.entryBetween ["stylixLookAndFeel"] ["writeBoundary"] ''
        stylixSavedDisplay=''${DISPLAY-}
        unset DISPLAY
      '';
      stylixRestoreDisplay = lib.hm.dag.entryAfter ["stylixLookAndFeel"] ''
        if [[ -n $stylixSavedDisplay ]]; then export DISPLAY=$stylixSavedDisplay; fi
      '';
    };

    # Stylix's qt target exports qtct+kvantum to every session, and plasmashell's QML can't load kvantum.
    xdg.configFile."plasma-workspace/env/qt-theme.sh" = lib.mkIf config.qt.enable {
      text = ''
        export QT_QPA_PLATFORMTHEME=kde
        export QT_STYLE_OVERRIDE=
      '';
    };
  }
