# The worktree-reconcile test over the real ghq-gitlab-group.sh, against its own stub ghq and glab.
{
  harness,
  pkgs,
  ...
}:
harness.check "polyrepo-scripts-script" ''
  export PATH=${pkgs.lib.makeBinPath [pkgs.bash pkgs.coreutils pkgs.findutils pkgs.gnugrep pkgs.gnused pkgs.jq pkgs.git]}:$PATH
  cp -r ${../.} scripts
  chmod -R u+w scripts
  patchShebangs scripts >/dev/null
  # The test writes its stubs with an env shebang, which the sandbox lacks.
  sed -i "s|^#!/usr/bin/env bash$|#!$(command -v bash)|" scripts/tests/ghq-gitlab-group-worktree-reconcile.sh
  scripts/tests/ghq-gitlab-group-worktree-reconcile.sh
''
