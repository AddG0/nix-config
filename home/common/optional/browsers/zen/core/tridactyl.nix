{
  config,
  pkgs,
  ...
}: let
  ghostty =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "${pkgs.ghostty-bin}/bin/ghostty"
    else "${pkgs.ghostty}/bin/ghostty --gtk-single-instance=false";
  # Read the current clipboard: pbpaste on macOS, wl-paste on Wayland/Linux.
  clipboardPaste =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "/usr/bin/pbpaste"
    else "${pkgs.wl-clipboard}/bin/wl-paste";
  nvim = "${config.programs.nixvim.build.package}/bin/nvim";
in {
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
    set editorcmd ${ghostty} -e ${nvim}

    " Close/restore on x/X (x default is the rarely-used "stop") so d/u are free
    " for half-page scroll — matches Vimium C and keeps the frequent motion on
    " the home keys; <C-d>/<C-u> still scroll too.
    bind x tabclose
    bind X undo
    bind d scrollpage 0.5
    bind u scrollpage -0.5

    " The mode indicator (bottom-right pill) overlays fullscreen video; drop it.
    set modeindicator false

    command clipnvim exclaim_quiet f=$(${pkgs.coreutils}/bin/mktemp --suffix=.json); ${clipboardPaste} > "$f"; ${ghostty} -e ${nvim} "$f"
    bind ;e composite hint -p ; clipnvim
  '';
}
