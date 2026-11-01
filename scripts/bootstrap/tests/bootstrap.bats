# The REAL bootstrap-nixos.sh against the stubs in ./script.nix: FAKE_* pick the
# target's state, $OUT collects what the stubs were asked to do.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert
  bats_load_library bats-file

  export OUT=$BATS_TEST_TMPDIR
  export REPO=$OUT/repo NIX_SECRETS_DIR=$OUT/nix-secrets XDG_STATE_HOME=$OUT/state HOME=$OUT/home
  export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
  export FAKE_ISO=yes FAKE_FACTER=ok FAKE_DISK_DEV=/dev/nvme0n1 FAKE_MNT=no FAKE_DISABLE_SOPS=true \
    FAKE_ANYWHERE_EXIT=0 FAKE_OLD_DISK_GONE=no FAKE_SOPS_FAIL=no FAKE_LOCK_REV='' FAKE_BUILD_FAIL=no \
    FAKE_SSH_DROP=no FAKE_PASSWORD_FILE=/tmp/from-layout HOST=newbox

  mkdir -p "$REPO/hosts/nixos" "$REPO/scripts" "$NIX_SECRETS_DIR" "$HOME"
  cp -r "$bootstrapDir" "$REPO/scripts/bootstrap"
  cp "$helpers" "$REPO/scripts/"
  chmod -R u+w "$REPO"
  printf 'keys:\n  hosts:\n    - &dev_oldhost age1old\n    - &otherhost age1otherhost\ncreation_rules:\n  - path_regex: secret.yaml\n    key_groups:\n      - age:\n          - *dev_oldhost\n' >"$NIX_SECRETS_DIR/.sops.yaml"
  printf 'data: ENC[x]\nsops:\n  age: []\n' >"$NIX_SECRETS_DIR/secret.yaml"
  "$realgit" init -q --bare "$OUT/origin.git"
  "$realgit" -C "$NIX_SECRETS_DIR" init -q -b main
  "$realgit" -C "$NIX_SECRETS_DIR" add -A
  "$realgit" -C "$NIX_SECRETS_DIR" commit -qm initial
  "$realgit" -C "$NIX_SECRETS_DIR" remote add origin "$OUT/origin.git"
  "$realgit" -C "$NIX_SECRETS_DIR" push -qu origin main
  printf '{"nodes":{"root":{"inputs":{"nix-secrets":"nix-secrets_2"}},"nix-secrets_2":{"locked":{"rev":"%s"}}}}\n' \
    "$("$realgit" -C "$NIX_SECRETS_DIR" rev-parse HEAD)" >"$REPO/flake.lock"
}

# bootstrap <stdin> <args...>: the script, with <stdin>'s escapes as its answers.
bootstrap() {
  printf '%b' "$1" >"$OUT/stdin"
  run bash "$REPO/scripts/bootstrap/bootstrap-nixos.sh" "${@:2}" <"$OUT/stdin"
}

# An existing host using sops, whose disko layout names a disk by id.
sops_host() {
  export HOST=oldhost FAKE_DISABLE_SOPS=false
  mkdir -p "$REPO/hosts/nixos/oldhost"
  printf '{...}: {imports = [inputs.disko.nixosModules.disko];}\n_module.args.disk = "/dev/disk/by-id/nvme-OLD_DISK_ABCDEF";\n' >"$REPO/hosts/nixos/oldhost/disko.nix"
}

secrets_commits() { "$realgit" -C "$NIX_SECRETS_DIR" rev-list --count HEAD; }
secrets_head() { "$realgit" -C "$NIX_SECRETS_DIR" rev-parse HEAD; }
origin_head() { "$realgit" -C "$OUT/origin.git" rev-parse main; }
registered_key() { yq 'explode(.) | .creation_rules[0].key_groups[0].age[0]' "$NIX_SECRETS_DIR/.sops.yaml"; }
installed_key() { ssh-to-age <"$OUT/extra/persist/etc/ssh/ssh_host_ed25519_key.pub"; }

@test "a hostname with capitals and underscores is rejected" {
  bootstrap "" Bad_Name 10.0.0.9
  assert_failure
  assert_output --partial "lowercase"
}

@test "an unknown option is rejected by name" {
  bootstrap "" newbox 10.0.0.9 --nope
  assert_failure
  assert_output --partial "Unknown option: --nope"
}

@test "a target not booted from the stick is refused and gets no host folder" {
  export FAKE_ISO=no
  bootstrap "" newbox 10.0.0.9
  assert_failure
  assert_output --partial "no installer stick"
  assert_not_exists "$REPO/hosts/nixos/newbox"
}

@test "a new disko host is scaffolded on the picked disk and installed with its passphrase" {
  bootstrap 'd\n1\nhunter2\nhunter2\nIAL123\n' newbox 10.0.0.9
  assert_success
  assert_file_contains "$REPO/hosts/nixos/newbox/disko.nix" 'disk = "/dev/disk/by-id/nvme-FAKE_SSD_SERIAL123"'
  assert_equal "$(jq .version "$REPO/hosts/nixos/newbox/facter.json")" 1
  assert_equal "$(stat -c %a "$REPO/hosts/nixos/newbox")" 755
  assert_line "  - Log in as tester with password 'changeme' and run passwd."
  assert_not_exists "$OUT/extra-files"

  run cat "$OUT/anywhere-args"
  assert_output --partial -- "--phases disko,install,reboot"
  # The path the host's own layout reads, not one the script picks.
  assert_output --partial -- "--disk-encryption-keys /tmp/from-layout "

  assert_equal "$(cat "$OUT/passphrase")" hunter2
  assert_equal "$(wc -c <"$OUT/passphrase")" 7

  run cat "$OUT/target-calls"
  assert_line inhibit

  run cat "$OUT/build-calls"
  assert_output --partial "system.build.toplevel"
  assert_output --partial "system.build.diskoScript"
}

@test "typing the hostname instead of the disk id wipes nothing and leaves no host folder" {
  bootstrap 'd\n1\nhunter2\nhunter2\nnewbox\n' newbox 10.0.0.9
  assert_failure
  assert_output --partial "Got 'newbox', not 'IAL123'; nothing was changed."
  assert_not_exists "$OUT/anywhere-args"
  assert_not_exists "$REPO/hosts/nixos/newbox"
}

@test "a failed nixos-facter stops the install without a half-made host folder" {
  export FAKE_FACTER=fail
  bootstrap 'd\n1\n' newbox 10.0.0.9
  assert_failure
  assert_output --partial "nixos-facter failed on 10.0.0.9."
  assert_not_exists "$REPO/hosts/nixos/newbox"
}

@test "a disk resolving to the installer stick is refused" {
  export FAKE_DISK_DEV=/dev/sdz
  bootstrap 'd\n1\n' newbox 10.0.0.9
  assert_failure
  assert_output --partial "is the installer stick"
}

@test "a new host on /mnt gets its hardware config from /mnt and installs without disko" {
  export FAKE_MNT=yes
  bootstrap 'm\n' newbox 10.0.0.9
  assert_success
  assert_file_not_empty "$REPO/hosts/nixos/newbox/hardware-configuration.nix"
  assert_not_exists "$REPO/hosts/nixos/newbox/disko.nix"
  run cat "$OUT/anywhere-args"
  assert_output --partial -- "--phases install,reboot"
  refute_output --partial disko
}

@test "a new host on /mnt is refused when nothing is mounted there" {
  export FAKE_MNT=no
  bootstrap 'm\n' newbox 10.0.0.9
  assert_failure
  assert_output --partial "Nothing mounted at /mnt"
}

@test "--debug traces the install but never the LUKS passphrase" {
  bootstrap 'd\n1\nhunter2\nhunter2\nIAL123\n' newbox 10.0.0.9 --debug
  assert_success
  assert_line "+ ask_luks_passphrase"
  assert_line "+ confirm_wipe"
  refute_output --partial hunter2
}

@test "an existing host on /mnt keeps its hardware config when nobody answers" {
  export HOST=kept FAKE_MNT=yes
  mkdir -p "$REPO/hosts/nixos/kept"
  printf '{...}: {}\n' >"$REPO/hosts/nixos/kept/default.nix"
  echo ORIGINAL >"$REPO/hosts/nixos/kept/hardware-configuration.nix"
  bootstrap "" kept 10.0.0.9
  assert_success
  assert_equal "$(cat "$REPO/hosts/nixos/kept/hardware-configuration.nix")" ORIGINAL
}

@test "a failed install warns the disk may be wiped and keeps the host" {
  export FAKE_ANYWHERE_EXIT=1
  bootstrap 'd\n1\nhunter2\nhunter2\nIAL123\n' newbox 10.0.0.9
  assert_failure
  assert_output --partial "may already be wiped"
  assert_exists "$REPO/hosts/nixos/newbox/disko.nix"
}

@test "a sops host's new key is installed, registered, re-encrypted to, pushed and locked" {
  sops_host
  bootstrap 'hunter2\nhunter2\nABCDEF\ny\n' oldhost 10.0.0.9
  assert_success
  assert_output --partial "oldhost is installed and rebooting."
  refute_output --partial changeme

  run cat "$OUT/extra-files"
  assert_line "./persist/etc/ssh/ssh_host_ed25519_key 600"

  assert_equal "$(registered_key)" "$(installed_key)"
  assert_equal "$(yq '.keys.hosts[1]' "$NIX_SECRETS_DIR/.sops.yaml")" age1otherhost
  run cat "$OUT/sops-calls"
  assert_line "updatekeys -y secret.yaml"
  assert_equal "$(secrets_commits)" 2
  assert_equal "$(origin_head)" "$(secrets_head)"
  assert_equal "$(jq -r '.nodes["nix-secrets_2"].locked.rev' "$REPO/flake.lock")" "$(origin_head)"
  assert_not_exists "$XDG_STATE_HOME/bootstrap/oldhost"
}

@test "a rerun after a failed install reuses the pending key and redoes none of the secrets work" {
  sops_host
  export FAKE_ANYWHERE_EXIT=1
  bootstrap 'hunter2\nhunter2\nABCDEF\ny\n' oldhost 10.0.0.9
  assert_failure
  assert_output --partial "nixos-anywhere failed."
  first_key=$(installed_key)
  assert_exists "$XDG_STATE_HOME/bootstrap/oldhost/ssh_host_ed25519_key"

  rm "$OUT/sops-calls" "$OUT/flake-calls" "$XDG_STATE_HOME/bootstrap/oldhost/ssh_host_ed25519_key.pub"
  echo "stray" >"$NIX_SECRETS_DIR/untracked.txt"
  echo "unrelated: edit" >>"$NIX_SECRETS_DIR/secret.yaml"
  export FAKE_ANYWHERE_EXIT=0
  bootstrap 'hunter2\nhunter2\nABCDEF\n' oldhost 10.0.0.9
  assert_success
  assert_output --partial "Reusing the pending host key"
  assert_output --partial "oldhost is installed and rebooting."
  refute_output --partial "Push"
  assert_equal "$(installed_key)" "$first_key"
  assert_equal "$(registered_key)" "$first_key"
  assert_equal "$(secrets_commits)" 2
  assert_not_exists "$OUT/sops-calls"
  # flake.lock already held the pushed nix-secrets.
  assert_not_exists "$OUT/flake-calls"

  run "$realgit" -C "$NIX_SECRETS_DIR" status --porcelain
  assert_line " M secret.yaml"
  assert_line "?? untracked.txt"
}

@test "a cut-short re-encrypt commits nothing, and the rerun finishes it without unrelated changes" {
  sops_host
  export FAKE_SOPS_FAIL=yes
  bootstrap 'hunter2\nhunter2\nABCDEF\n' oldhost 10.0.0.9
  assert_failure
  assert_output --partial "sops updatekeys failed"
  assert_equal "$(secrets_commits)" 1

  echo "note: mine" >"$NIX_SECRETS_DIR/notes.yaml"
  "$realgit" -C "$NIX_SECRETS_DIR" add notes.yaml
  "$realgit" -C "$NIX_SECRETS_DIR" commit -qm notes
  echo "note: edited" >"$NIX_SECRETS_DIR/notes.yaml"
  echo "staged: mine" >"$NIX_SECRETS_DIR/staged.yaml"
  "$realgit" -C "$NIX_SECRETS_DIR" add staged.yaml
  export FAKE_SOPS_FAIL=no
  bootstrap 'hunter2\nhunter2\nABCDEF\ny\n' oldhost 10.0.0.9
  assert_success
  assert_equal "$(secrets_commits)" 3
  assert_equal "$(registered_key)" "$(installed_key)"

  run "$realgit" -C "$NIX_SECRETS_DIR" diff --quiet HEAD -- notes.yaml
  assert_failure
  run "$realgit" -C "$NIX_SECRETS_DIR" show --name-only --format= HEAD
  assert_line .sops.yaml
  refute_line staged.yaml
}

@test "a nix-secrets branch without an upstream is explained before anything installs" {
  sops_host
  "$realgit" -C "$NIX_SECRETS_DIR" branch -q --unset-upstream
  bootstrap 'hunter2\nhunter2\nABCDEF\ny\n' oldhost 10.0.0.9
  assert_failure
  assert_output --partial "no upstream"
  assert_not_exists "$OUT/anywhere-args"
}

@test "a flake.lock left off the pushed nix-secrets is refused before anything installs" {
  sops_host
  export FAKE_LOCK_REV=0000000000000000000000000000000000000000
  bootstrap 'hunter2\nhunter2\nABCDEF\ny\n' oldhost 10.0.0.9
  assert_failure
  assert_output --partial "not the pushed"
  assert_not_exists "$OUT/anywhere-args"
}

@test "a nix-secrets with nothing encrypted is refused and the host key is not committed" {
  sops_host
  printf 'data: plain\n' >"$NIX_SECRETS_DIR/secret.yaml"
  "$realgit" -C "$NIX_SECRETS_DIR" commit -qam "no secrets"
  bootstrap 'hunter2\nhunter2\nABCDEF\ny\n' oldhost 10.0.0.9
  assert_failure
  assert_output --partial "Found no sops-encrypted files"
  assert_equal "$(secrets_commits)" 2
}

@test "declining the push installs nothing, and the rerun pushes the existing commit" {
  sops_host
  bootstrap 'hunter2\nhunter2\nABCDEF\nn\n' oldhost 10.0.0.9
  assert_failure
  assert_output --partial "Not pushed and nothing installed"
  assert_not_exists "$OUT/anywhere-args"
  assert_not_equal "$(origin_head)" "$(secrets_head)"

  bootstrap 'hunter2\nhunter2\nABCDEF\ny\n' oldhost 10.0.0.9
  assert_success
  assert_equal "$(secrets_commits)" 2
  assert_equal "$(origin_head)" "$(secrets_head)"
}

@test "a host whose disk was swapped installs onto the picked disk, rewriting the host's files" {
  sops_host
  export FAKE_OLD_DISK_GONE=yes
  bootstrap '1\nhunter2\nhunter2\nIAL123\ny\n' oldhost 10.0.0.9
  assert_success
  assert_file_contains "$REPO/hosts/nixos/oldhost/disko.nix" 'disk = "/dev/disk/by-id/nvme-FAKE_SSD_SERIAL123"'
  assert_file_not_contains "$REPO/hosts/nixos/oldhost/disko.nix" OLD_DISK
}

@test "a dropped ssh connection is reported, not taken as a missing disk" {
  sops_host
  export FAKE_SSH_DROP=yes
  bootstrap 'hunter2\nhunter2\nABCDEF\n' oldhost 10.0.0.9
  assert_failure
  assert_output --partial "Building oldhost; the prompts come after this"
  assert_output --partial "Lost the ssh connection to root@10.0.0.9."
  refute_output --partial "pick the disk"
  assert_file_contains "$REPO/hosts/nixos/oldhost/disko.nix" OLD_DISK_ABCDEF
}

@test "a failing build stops before the prompts and the key rotation" {
  sops_host
  export FAKE_BUILD_FAIL=yes
  bootstrap "" oldhost 10.0.0.9
  assert_failure
  assert_output --partial "Building .#oldhost failed; see the nix error above. Nothing on 10.0.0.9 was touched."
  refute_output --regexp "passphrase|Type the last 6|Push"
  assert_equal "$(secrets_commits)" 1
}

@test "uncommitted nix-secrets changes are refused, not committed over" {
  sops_host
  echo unrelated >>"$NIX_SECRETS_DIR/secret.yaml"
  bootstrap 'hunter2\nhunter2\nABCDEF\n' oldhost 10.0.0.9
  assert_failure
  assert_output --partial "uncommitted changes"
  assert_equal "$(secrets_commits)" 1
}
