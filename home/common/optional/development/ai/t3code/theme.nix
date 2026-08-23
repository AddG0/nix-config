{config, ...}: let
  c = config.lib.stylix.colors.withHashtag;
in {
  # Families only: t3code sizes are CSS pixels, stylix's are toolkit points.
  programs.t3code.clientSettings.settings = {
    fontFamilySans = config.stylix.fonts.sansSerif.name;
    fontFamilyCode = config.stylix.fonts.monospace.name;
    fontFamilyComposer = config.stylix.fonts.sansSerif.name;
    fontFamilyTerminal = config.stylix.fonts.monospace.name;
  };

  # base16 has no hue-tinted surfaces, so the *Surface roles land on base01
  # rather than the canvas/accent blends t3code's own palettes use.
  programs.t3code.theme = {
    enable = true;
    id = "stylix";
    label = "Stylix";

    colors = {
      canvas = c.base00;
      chrome = c.base00;
      toolbar = c.base00;
      toolbarForeground = c.base05;
      toolbarBorder = c.base02;
      toolbarControl = c.base01;
      toolbarControlForeground = c.base05;
      toolbarControlHover = c.base02;

      surface = c.base00;
      surfaceRaised = c.base01;
      surfaceOverlay = c.base01;

      text = c.base05;
      textMuted = c.base04;
      border = c.base02;
      input = c.base02;
      focus = c.base0D;

      accent = c.base0D;
      accentForeground = c.base00;
      accentSurface = c.base02;
      accentSurfaceForeground = c.base05;

      secondary = c.base01;
      secondaryForeground = c.base05;
      muted = c.base01;
      mutedForeground = c.base04;
      placeholder = c.base03;
      secondaryLabel = c.base04;
      iconMuted = c.base04;

      error = c.base08;
      errorForeground = c.base08;
      errorSurface = c.base01;
      warning = c.base0A;
      warningForeground = c.base0A;
      warningSurface = c.base01;
      update = c.base0D;
      updateForeground = c.base0D;
      updateSurface = c.base01;

      messageSurface = c.base01;
      messageForeground = c.base05;
      messageAction = c.base0D;
      messageActionForeground = c.base00;
      messageActionHover = c.base0C;

      codeBackground = c.base01;
      codeForeground = c.base05;

      sidebar = c.base01;
      sidebarForeground = c.base05;
      sidebarMutedForeground = c.base04;
      sidebarControlSurface = c.base02;
      sidebarRowHover = c.base02;
      sidebarRowActive = c.base02;
      sidebarRowSelected = c.base03;
      sidebarBorder = c.base02;

      terminalBackground = c.base00;
      terminalForeground = c.base05;
      terminalCursor = c.base0D;
      terminalSelection = c.base02;
      terminalScrollbar = c.base02;
      terminalScrollbarHover = c.base03;
    };
  };
}
