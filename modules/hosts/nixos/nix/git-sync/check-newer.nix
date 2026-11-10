# git-sync's ExecCondition: exits 0 when the remote flake moved past the running system, 1 to skip the run, 255 to fail it.
{
  writeShellApplication,
  coreutils,
  git,
  iputils,
  jq,
  nix,
  openssh,
  flakeRef,
  lastBuiltRecord,
  waitForNetwork,
}:
writeShellApplication {
  name = "nix-remote-rebuild-check-newer";
  runtimeInputs = [coreutils git iputils jq nix openssh];
  text = ''
    # Exit 1 would skip the run, so a failure nobody expected fails the unit instead.
    trap 'exit 255' ERR

    # Offline, nix answers from its cache, which passes for "nothing new"; the subshell turns a timeout into 255.
    (
      log() { echo "$*"; }
      ${waitForNetwork}
    )

    metadata=$(nix flake metadata "${flakeRef}" --refresh --json)
    remote=$(jq -r '.locked.narHash' <<<"$metadata")
    remote_rev=$(jq -r '.locked.rev // empty' <<<"$metadata")

    if [ -f "${lastBuiltRecord}" ] && [ "$(cat "${lastBuiltRecord}")" = "$remote" ]; then
      echo "Remote flake unchanged since last rebuild ($remote); skipping."
      exit 1
    fi

    # Exits 1 for a system built without a revision: then only the narHash above decides.
    running=$("''${CURRENT_SYSTEM:-/run/current-system}/sw/bin/nixos-version" --configuration-revision 2>/dev/null) || running=""
    base=''${running%-dirty}
    if [ -n "$base" ] && [ -n "$remote_rev" ]; then
      if [ "$base" = "$remote_rev" ]; then
        echo "Running $running, built from the remote's current commit; skipping."
        exit 1
      fi
      git_url=$(jq -r -f ${./locked-git-url.jq} <<<"$metadata")
      history=$(mktemp -d)
      trap 'rm -rf "$history"' EXIT
      git -C "$history" init -q
      # 255 fails the unit: a history it cannot read must not pass for "behind".
      git -C "$history" fetch -q --filter=blob:none "$git_url" "$remote_rev" || {
        echo "Cannot fetch $remote_rev from $git_url to compare with running $running."
        exit 255
      }
      if ! git -C "$history" merge-base --is-ancestor "$base" "$remote_rev" 2>/dev/null; then
        echo "Running $running is not in the remote's history (a hand deploy from an unpushed commit); skipping."
        exit 1
      fi
    fi
    echo "Remote flake changed ($remote_rev) and contains running ''${running:-unknown}; proceeding with rebuild."
    exit 0
  '';
}
