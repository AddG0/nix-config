{
  config,
  pkgs,
  ...
}: let
  gwadd = pkgs.writeShellApplication {
    name = "gwadd";
    runtimeInputs = with pkgs; [git gwq gawk sesh];
    text = builtins.readFile ./scripts/gwadd.sh;
  };
in {
  home.packages = [pkgs.gwq gwadd];

  # Worktrees live next to clones, with `--<branch>` suffix for disambiguation.
  # e.g. ~/Projects/code/.../ai-eng-framework clone →
  #      ~/Projects/code/.../ai-eng-framework--ENG-123 worktree
  #
  # `--` separator (not `=`) avoids the `-javaagent:<path>=<args>` collision
  # that breaks JaCoCo in Gradle/Maven test runs.
  #
  # The template here is gwq's fallback; `gwadd` is the preferred entrypoint
  # because gwq's URL parser drops GitLab subgroups (d-kuro/gwq#85, partially
  # fixed in PR #87) and gets fooled by insteadOf URL rewrites. The wrapper
  # passes an explicit path so neither comes into play.
  xdg.configFile."gwq/config.toml".text = ''
    [worktree]
    basedir = "${config.polyrepo.ghqRoot}"

    [naming]
    template = "{{.Host}}/{{.Owner}}/{{.Repository}}--{{.Branch}}"
  '';
}
