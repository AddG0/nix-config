{
  lib,
  mkPlugin,
}:
mkPlugin {
  pname = "obsidian-kanban-bases-view";
  version = "0.11.0";
  repo = "xiwcx/obsidian-bases-kanban";
  manifestId = "kanban-bases-view";

  hashes = {
    "main.js" = "sha256-+n61yPSBUMnHRleFXl+4VqzR4h5FdwTWJs4J7tXuywI=";
    "manifest.json" = "sha256-m9itrKIway1xOzT93Wtw5B6YVseFhMkT/Hw3kliSZl4=";
    "styles.css" = "sha256-Z1ytPm50ibPKFrv1GNP9Zb2oGOPIU/pzRgd4rKhKToQ=";
  };

  meta = {
    description = "Kanban-style drag-and-drop custom view for Obsidian Bases";
    homepage = "https://github.com/xiwcx/obsidian-bases-kanban";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
