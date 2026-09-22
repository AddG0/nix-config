# Obsidian community plugins
pkgs: let
  mkPlugin = pkgs.callPackage ./mk-plugin.nix {};
in {
  kanban-bases-view = pkgs.callPackage ./kanban-bases-view {inherit mkPlugin;};
  self-hosted-livesync = pkgs.callPackage ./self-hosted-livesync {inherit mkPlugin;};
}
