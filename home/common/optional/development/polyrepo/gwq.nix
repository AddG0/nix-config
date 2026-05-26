{pkgs, ...}: {
  home.packages = [pkgs.gwq];

  # Worktrees live next to clones, with `=<branch>` suffix for disambiguation.
  # e.g. ~/Projects/code/.../ShipperWS clone  →  ~/Projects/code/.../ShipperWS=feat-X worktree
  xdg.configFile."gwq/config.toml".text = ''
    [worktree]
    basedir = "~/Projects/code"

    [naming]
    template = "{{.Host}}/{{.Owner}}/{{.Repository}}={{.Branch}}"
  '';
}
