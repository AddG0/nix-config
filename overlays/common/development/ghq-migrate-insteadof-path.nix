# `ghq migrate` names a repo's destination from `git remote get-url`, which
# applies insteadOf. insteadOf rewrites for transport, so a work repo whose
# config holds https://gitlab.com/ShipperHQ/… but routes over the gitlab-work
# ssh alias migrates to <root>/gitlab-work/ShipperHQ/… instead of
# <root>/gitlab.com/…. Reading the raw config names the path after the real
# host and leaves cloning — the part insteadOf exists for — untouched.
#
# `ghq get` takes its URL on argv, so migrate is the only command affected.
# Drop once fixed upstream (x-motemen/ghq).
_: _final: prev: {
  ghq = prev.ghq.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./ghq-migrate-insteadof-path.patch];
  });
}
