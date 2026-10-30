{
  lib,
  mkPlugin,
}:
mkPlugin {
  pname = "obsidian-kanban-bases-view";
  version = "0.10.6";
  repo = "xiwcx/obsidian-bases-kanban";
  manifestId = "kanban-bases-view";

  hashes = {
    "main.js" = "sha256-FUzskANsH1gsexrScMXuVkZpCSWd0xu55guR8TnFl+M=";
    "manifest.json" = "sha256-/mIiWQsA3W2o68YzgREUfABLz4ZXV7UIS9ptI5btPhk=";
    "styles.css" = "sha256-/kRK9l8Yj1uLv2c5NkFUvkmKYvs5PjlPDLPrI96+Ipk=";
  };

  meta = {
    description = "Kanban-style drag-and-drop custom view for Obsidian Bases";
    homepage = "https://github.com/xiwcx/obsidian-bases-kanban";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
