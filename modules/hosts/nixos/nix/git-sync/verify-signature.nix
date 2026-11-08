# Exits 0 when commit $3 of git remote $2 is signed by a key in allowed-signers file $1, 1 with the reason when it is not.
{
  writeShellApplication,
  coreutils,
  git,
  openssh,
}:
writeShellApplication {
  name = "nix-remote-rebuild-verify-signature";
  runtimeInputs = [coreutils git openssh];
  text = ''
    if [ $# -ne 3 ]; then
      echo "usage: nix-remote-rebuild-verify-signature <allowed-signers> <git-url> <rev>" >&2
      exit 2
    fi
    allowed_signers=$1
    git_url=$2
    rev=$3

    if [ -z "$git_url" ] || [ -z "$rev" ]; then
      echo "Cannot verify a signature without a git remote and revision (remote '$git_url', rev '$rev')."
      exit 1
    fi

    checkout=$(mktemp -d)
    trap 'rm -rf "$checkout"' EXIT
    git -C "$checkout" init -q
    if ! git -C "$checkout" fetch -q --depth=1 "$git_url" "$rev"; then
      echo "Cannot fetch $rev from $git_url to verify its signature."
      exit 1
    fi
    if ! git -C "$checkout" -c gpg.ssh.allowedSignersFile="$allowed_signers" verify-commit "$rev"; then
      echo "$rev from $git_url is not signed by an allowed key."
      exit 1
    fi
    echo "Verified signature on $rev."
  '';
}
