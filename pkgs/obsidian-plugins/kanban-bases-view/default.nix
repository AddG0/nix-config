{
  lib,
  mkPlugin,
}:
mkPlugin {
  pname = "obsidian-kanban-bases-view";
  version = "0.10.4";
  repo = "xiwcx/obsidian-bases-kanban";

  hashes = {
    "main.js" = "sha256-b3gqbpBsIeMK/vH9288B0DGZIJTIQRSNvPazkpwEs64=";
    "manifest.json" = "sha256-bZsfQho48xKVjpMO6EiinHyfnrKznDxjS9rw0qOxAis=";
    "styles.css" = "sha256-/kRK9l8Yj1uLv2c5NkFUvkmKYvs5PjlPDLPrI96+Ipk=";
  };

  # 0.10.4 builds every board element with `<document>.createDiv()`, which throws
  # and leaves the board empty; see xiwcx/obsidian-bases-kanban#113.
  postInstall = ''
    substituteInPlace $out/main.js \
      --replace-fail 'doc.createDiv()' 'doc.createElement("div")'
  '';

  meta = {
    description = "Kanban-style drag-and-drop custom view for Obsidian Bases";
    homepage = "https://github.com/xiwcx/obsidian-bases-kanban";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
