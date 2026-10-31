{mkStorePlugin}:
(mkStorePlugin {
  pname = "SDH-CssLoader";
  version = "2.1.3";
  hash = "99beaf1374af82408e6d056e0b0147e5fca544e1035fa7ab88419231697bc231";
  storeName = "CSS Loader";
  meta.description = "Theme the Steam UI with DeckThemes CSS";
})
.overrideAttrs {
  # Steam's themes_custom link is made only when absent, so one left pointing at another themes dir would stay dangling.
  postInstall = ''
    substituteInPlace "$out/css_utils.py" \
      --replace-fail "        if not os.path.exists(dst):" \
                     "        if os.path.islink(dst) and os.readlink(dst) != src:
                os.unlink(dst)
            if not os.path.lexists(dst):"
  '';
}
