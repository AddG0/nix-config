{
  config,
  pkgs,
  ...
}: {
  programs.zen-browser.profiles.default.extensions.packages = [pkgs.firefox-addons.tridactyl];

  # Native messenger, wrapped into Zen (not the shell PATH) — lets :editor
  # (Ctrl+I) open text fields in Neovim and lets Tridactyl load tridactylrc
  # from disk.
  programs.zen-browser.nativeMessagingHosts = [pkgs.tridactyl-native];

  # --gtk-single-instance=false makes ghostty block until nvim closes, so the
  # edited text syncs back instead of being read while the file is still empty.
  # clipnvim / ;e: open a non-editable box's text in nvim (;p hint-copies it) —
  # for JSON viewers etc. that :editor can't attach to. Read-only, no sync back.
  xdg.configFile."tridactyl/tridactylrc".text = ''
    set editorcmd ${pkgs.ghostty}/bin/ghostty --gtk-single-instance=false -e ${config.programs.nixvim.build.package}/bin/nvim

    command clipnvim exclaim_quiet f=$(${pkgs.coreutils}/bin/mktemp --suffix=.json); ${pkgs.wl-clipboard}/bin/wl-paste > "$f"; ${pkgs.ghostty}/bin/ghostty --gtk-single-instance=false -e ${config.programs.nixvim.build.package}/bin/nvim "$f"
    bind ;e composite hint -p ; clipnvim
  '';
}
