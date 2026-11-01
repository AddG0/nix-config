# just bootstrap: what it writes, what it refuses, what it hands nixos-anywhere, and what a rerun skips, against a stubbed stick.
{
  pkgs,
  self,
  ...
}: let
  # The target, answering only the commands the script sends; FAKE_* pick its state per case.
  ssh = pkgs.writeShellScriptBin "ssh" ''
    while [ $# -gt 0 ] && [ "''${1#root@}" = "$1" ]; do shift; done
    shift
    cmd="$*"
    # The target runs what ssh sends as one command line, so it has to parse as one.
    bash -n -c "$cmd" || { echo "ssh stub: the remote command does not parse: $cmd" >&2; exit 2; }
    case "$cmd" in
      true) exit 0 ;;
      *"SOURCE /iso"*) [ "$FAKE_ISO" = yes ] && echo /dev/sdz || exit 1 ;;
      "stick=/dev/sdz; seen="*"for pass in"*) printf '%s\n' "/dev/disk/by-id/nvme-FAKE_SSD_SERIAL123 1T FAKE SSD" ;;
      nixos-facter) [ "$FAKE_FACTER" = ok ] && echo '{"version":1,"system":"x86_64-linux"}' || exit 1 ;;
      "readlink -e "*) [ "$FAKE_SSH_DROP" != yes ] || exit 255 ;;&
      "readlink -e "*OLD_DISK*) [ "$FAKE_OLD_DISK_GONE" = yes ] && exit 1 || echo "$FAKE_DISK_DEV" ;;
      "readlink -e "*) echo "$FAKE_DISK_DEV" ;;
      "lsblk -dno SIZE,MODEL "*) echo "1T FAKE SSD" ;;
      "findmnt /mnt" | "findmnt /mnt/boot") [ "$FAKE_MNT" = yes ] ;;
      "nixos-generate-config "*) echo '{...}: {}' ;;
      "systemd-inhibit --list"*) [ -e "$OUT/target-calls" ] ;;
      "systemd-run "*"systemd-inhibit --what=sleep"*) echo inhibit >>"$OUT/target-calls" ;;
      *) echo "ssh stub: unexpected command: $cmd" >&2; exit 1 ;;
    esac
  '';
  # nix-config's git only answers; nix-secrets (git -C) is a real repository with a bare origin.
  git = pkgs.writeShellScriptBin "git" ''
    [ "$1" != -C ] || exec ${pkgs.git}/bin/git "$@"
    case "$1" in
      rev-parse) echo "$REPO" ;;
      add | rm) ;;
      *) echo "git stub: unexpected $*" >&2; exit 1 ;;
    esac
  '';
  # Re-encrypting changes nothing visible here; the calls are what is checked. FAKE_SOPS_FAIL cuts it short.
  sops = pkgs.writeShellScriptBin "sops" ''
    [ "$FAKE_SOPS_FAIL" != yes ] || exit 1
    echo "$*" >>"$OUT/sops-calls"
  '';
  # Evaluates nothing: answers each attribute the script reads, locks nix-secrets at its HEAD, records the nixos-anywhere call.
  nix = pkgs.writeShellScriptBin "nix" ''
    if [ "$1" = flake ]; then
      echo "$*" >>"$OUT/flake-calls"
      rev=''${FAKE_LOCK_REV:-$(${pkgs.git}/bin/git -C "$NIX_SECRETS_DIR" rev-parse HEAD)}
      ${pkgs.jq}/bin/jq --arg rev "$rev" '.nodes["nix-secrets_2"].locked.rev = $rev' "$REPO/flake.lock" >"$REPO/flake.lock.new"
      mv "$REPO/flake.lock.new" "$REPO/flake.lock"
      exit 0
    fi
    if [ "$1" = build ]; then
      shift 2
      echo "$*" >>"$OUT/build-calls"
      [ "$FAKE_BUILD_FAIL" != yes ]
      exit
    fi
    if [ "$1" = run ]; then
      shift 3
      echo "$*" >"$OUT/anywhere-args"
      rm -rf "$OUT/extra" "$OUT/extra-files"
      while [ $# -gt 0 ]; do
        case "$1" in
          --disk-encryption-keys) cp "$3" "$OUT/passphrase"; shift 2 ;;
          --extra-files) (cd "$2" && find . -type f -printf '%p %m\n' | sort) >"$OUT/extra-files"; cp -r "$2" "$OUT/extra"; shift ;;
        esac
        shift
      done
      exit "$FAKE_ANYWHERE_EXIT"
    fi
    attr="$3"
    case "$attr" in
      *toplevel.drvPath) echo /nix/store/fake.drv ;;
      *hostSpec.disableSops) echo "$FAKE_DISABLE_SOPS" ;;
      *.options) [ -e "$REPO/hosts/nixos/$HOST/disko.nix" ] && echo true || echo false ;;
      *disko.devices.disk) echo '["main"]' ;;
      *disko.devices.disk.main.content.partitions) echo "[\"$FAKE_PASSWORD_FILE\"]" ;;
      *disko.devices.disk.main.device) sed -n 's/.*disk = "\(.*\)";/\1/p' "$REPO/hosts/nixos/$HOST/disko.nix" ;;
      *boot.initrd.luks.devices) echo '["crypted"]' ;;
      *sops.age.sshKeyPaths) echo /persist/etc/ssh/ssh_host_ed25519_key ;;
      *hostSpec.primaryUsername) echo addg ;;
      *) echo "nix stub: unexpected $*" >&2; exit 1 ;;
    esac
  '';
in
  pkgs.runCommand "bootstrap-nixos" {
    nativeBuildInputs = [ssh git nix sops pkgs.jq pkgs.openssh pkgs.ssh-to-age pkgs.yq-go];
  } ''
    fail() { echo "FAIL: $*" >&2; exit 1; }
    export HOME=$PWD/home GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
    realgit=${pkgs.git}/bin/git

    # setup <case>: a fresh nix-config, nix-secrets (pushed to a bare origin) and pending-key state per case.
    setup() {
      export OUT=$PWD/$1 REPO=$PWD/$1/repo NIX_SECRETS_DIR=$PWD/$1/nix-secrets XDG_STATE_HOME=$PWD/$1/state
      mkdir -p "$REPO/hosts/nixos" "$REPO/scripts" "$NIX_SECRETS_DIR"
      cp -r ${self}/scripts/bootstrap "$REPO/scripts/bootstrap"
      cp ${self}/scripts/helpers.sh "$REPO/scripts/"
      chmod -R u+w "$REPO"
      [ -z "$EXISTING" ] || cp -r "$EXISTING" "$REPO/hosts/nixos/$HOST"
      printf 'keys:\n  hosts:\n    - &dev_zephy age1old\n    - &freya age1freya\ncreation_rules:\n  - path_regex: secret.yaml\n    key_groups:\n      - age:\n          - *dev_zephy\n' >"$NIX_SECRETS_DIR/.sops.yaml"
      printf 'data: ENC[x]\nsops:\n  age: []\n' >"$NIX_SECRETS_DIR/secret.yaml"
      $realgit init -q --bare "$OUT/origin.git"
      $realgit -C "$NIX_SECRETS_DIR" init -q -b main
      $realgit -C "$NIX_SECRETS_DIR" add -A
      $realgit -C "$NIX_SECRETS_DIR" commit -qm initial
      $realgit -C "$NIX_SECRETS_DIR" remote add origin "$OUT/origin.git"
      $realgit -C "$NIX_SECRETS_DIR" push -qu origin main
      printf '{"nodes":{"root":{"inputs":{"nix-secrets":"nix-secrets_2"}},"nix-secrets_2":{"locked":{"rev":"%s"}}}}\n' \
        "$($realgit -C "$NIX_SECRETS_DIR" rev-parse HEAD)" >"$REPO/flake.lock"
    }
    # again <stdin> <args...>: runs the script in the current case; status in $status, output in $OUT/log.
    again() {
      status=0
      printf "$1" | bash "$REPO/scripts/bootstrap/bootstrap-nixos.sh" "''${@:2}" >"$OUT/log" 2>&1 || status=$?
    }
    run() {
      setup "$1"
      shift
      again "$@"
    }
    defaults() {
      export FAKE_ISO=yes FAKE_FACTER=ok FAKE_DISK_DEV=/dev/nvme0n1 FAKE_MNT=no FAKE_DISABLE_SOPS=true FAKE_ANYWHERE_EXIT=0 FAKE_OLD_DISK_GONE=no FAKE_SOPS_FAIL=no FAKE_LOCK_REV= FAKE_BUILD_FAIL=no FAKE_SSH_DROP=no FAKE_PASSWORD_FILE=/tmp/from-layout EXISTING= HOST=newbox
    }
    secrets_commits() { $realgit -C "$NIX_SECRETS_DIR" rev-list --count HEAD; }
    secrets_head() { $realgit -C "$NIX_SECRETS_DIR" rev-parse HEAD; }
    origin_head() { $realgit -C "$OUT/origin.git" rev-parse main; }
    registered_key() { yq 'explode(.) | .creation_rules[0].key_groups[0].age[0]' "$NIX_SECRETS_DIR/.sops.yaml"; }
    installed_key() { ssh-to-age <"$OUT/extra/persist/etc/ssh/ssh_host_ed25519_key.pub"; }

    defaults
    run bad-name "" Bad_Name 10.0.0.9
    [ $status -ne 0 ] && grep -q "lowercase" bad-name/log || fail "a hostname with capitals and underscores was not rejected"

    defaults
    run bad-option "" newbox 10.0.0.9 --nope
    [ $status -ne 0 ] && grep -q "Unknown option: --nope" bad-option/log || fail "an unknown option was not rejected by name"

    defaults
    FAKE_ISO=no run no-stick "" newbox 10.0.0.9
    [ $status -ne 0 ] && grep -q "no installer stick" no-stick/log || fail "a target not booted from the stick was not refused: $(cat no-stick/log)"
    [ ! -e no-stick/repo/hosts/nixos/newbox ] || fail "a refused target still left a host folder"

    defaults
    run new-disko 'd\n1\nhunter2\nhunter2\nIAL123\n' newbox 10.0.0.9
    [ $status -eq 0 ] || fail "a new disko host did not install: $(cat new-disko/log)"
    grep -q 'disk = "/dev/disk/by-id/nvme-FAKE_SSD_SERIAL123"' new-disko/repo/hosts/nixos/newbox/disko.nix || fail "the picked disk is not in disko.nix"
    jq -e .version new-disko/repo/hosts/nixos/newbox/facter.json >/dev/null || fail "facter.json was not written"
    [ "$(stat -c %a new-disko/repo/hosts/nixos/newbox)" = 755 ] || fail "the new host folder is not 755"
    grep -q -- "--phases disko,install,reboot" new-disko/anywhere-args || fail "a disko host was not installed with the disko phase: $(cat new-disko/anywhere-args)"
    grep -q -- "--disk-encryption-keys /tmp/from-layout " new-disko/anywhere-args || fail "the passphrase did not go to the password file the host's layout reads: $(cat new-disko/anywhere-args)"
    [ "$(cat new-disko/passphrase)" = hunter2 ] && [ "$(wc -c <new-disko/passphrase)" = 7 ] || fail "the LUKS passphrase file is not exactly the passphrase"
    grep -q "changeme" new-disko/log || fail "a host without sops was not told its password is changeme"
    grep -qx inhibit new-disko/target-calls || fail "the stick was not kept awake during the install"
    grep -q "system.build.toplevel" new-disko/build-calls && grep -q "system.build.diskoScript" new-disko/build-calls || fail "the system and its disko script were not built before installing: $(cat new-disko/build-calls)"
    [ ! -e new-disko/extra-files ] || fail "a host without sops was given a host key"

    defaults
    run wrong-confirm 'd\n1\nhunter2\nhunter2\nnewbox\n' newbox 10.0.0.9
    [ $status -ne 0 ] || fail "typing the hostname instead of the disk id still wiped"
    [ ! -e wrong-confirm/anywhere-args ] || fail "nixos-anywhere ran without the disk being confirmed"
    [ ! -e wrong-confirm/repo/hosts/nixos/newbox ] || fail "an unconfirmed new host left its folder behind"

    defaults
    FAKE_FACTER=fail run facter-fails 'd\n1\n' newbox 10.0.0.9
    [ $status -ne 0 ] || fail "a failed nixos-facter did not stop the install"
    [ ! -e facter-fails/repo/hosts/nixos/newbox ] || fail "a failed nixos-facter left a half-made host folder"

    defaults
    FAKE_DISK_DEV=/dev/sdz run disk-is-stick 'd\n1\n' newbox 10.0.0.9
    [ $status -ne 0 ] && grep -q "is the installer stick" disk-is-stick/log || fail "a disk resolving to the stick was not refused: $(cat disk-is-stick/log)"

    defaults
    FAKE_MNT=yes run new-mounted 'm\n' newbox 10.0.0.9
    [ $status -eq 0 ] || fail "a new host on /mnt did not install: $(cat new-mounted/log)"
    [ -s new-mounted/repo/hosts/nixos/newbox/hardware-configuration.nix ] || fail "hardware-configuration.nix was not written from /mnt"
    [ ! -e new-mounted/repo/hosts/nixos/newbox/disko.nix ] || fail "a host on /mnt got a disko layout"
    grep -q -- "--phases install,reboot" new-mounted/anywhere-args && ! grep -q disko new-mounted/anywhere-args || fail "a host on /mnt was not installed without the disko phase"

    defaults
    FAKE_MNT=no run mounted-nothing 'm\n' newbox 10.0.0.9
    [ $status -ne 0 ] && grep -q "Nothing mounted at /mnt" mounted-nothing/log || fail "an empty /mnt was not refused"

    defaults
    run debug-trace 'd\n1\nhunter2\nhunter2\nIAL123\n' newbox 10.0.0.9 --debug
    [ $status -eq 0 ] || fail "a --debug install did not complete: $(tail -5 debug-trace/log)"
    ! grep -q hunter2 debug-trace/log || fail "--debug printed the LUKS passphrase"

    mkdir kept && printf '{...}: {}\n' >kept/default.nix && echo ORIGINAL >kept/hardware-configuration.nix
    defaults
    EXISTING=$PWD/kept HOST=kept FAKE_MNT=yes run kept-no-answer "" kept 10.0.0.9
    [ $status -eq 0 ] || fail "an existing host on /mnt did not install without a terminal: $(cat kept-no-answer/log)"
    [ "$(cat kept-no-answer/repo/hosts/nixos/kept/hardware-configuration.nix)" = ORIGINAL ] || fail "end of input was taken as yes and regenerated the hardware config"

    defaults
    FAKE_ANYWHERE_EXIT=1 run anywhere-fails 'd\n1\nhunter2\nhunter2\nIAL123\n' newbox 10.0.0.9
    [ $status -ne 0 ] && grep -q "may already be wiped" anywhere-fails/log || fail "a failed install did not warn the disk may be wiped"
    [ -e anywhere-fails/repo/hosts/nixos/newbox/disko.nix ] || fail "a failed install removed the host it may have half-installed"

    mkdir zephy && printf '{...}: {imports = [inputs.disko.nixosModules.disko];}\n_module.args.disk = "/dev/disk/by-id/nvme-OLD_DISK_ABCDEF";\n' >zephy/disko.nix
    sops_host() {
      defaults
      export EXISTING=$PWD/zephy HOST=zephy FAKE_DISABLE_SOPS=false
    }

    sops_host
    run sops-host 'hunter2\nhunter2\nABCDEF\ny\n' zephy 10.0.0.9
    [ $status -eq 0 ] || fail "an existing sops host did not reinstall: $(cat sops-host/log)"
    grep -qx "./persist/etc/ssh/ssh_host_ed25519_key 600" sops-host/extra-files || fail "the new host key did not go to the path sops reads, mode 600: $(cat sops-host/extra-files)"
    [ "$(registered_key)" = "$(installed_key)" ] || fail "the secrets rules do not point at the installed host key"
    [ "$(yq '.keys.hosts[1]' sops-host/nix-secrets/.sops.yaml)" = age1freya ] || fail "another host's key changed"
    grep -qx "updatekeys -y secret.yaml" sops-host/sops-calls || fail "the secrets were not re-encrypted to the new key"
    [ "$(secrets_commits)" = 2 ] && [ "$(origin_head)" = "$(secrets_head)" ] || fail "the new host key was not committed once and pushed"
    [ "$(jq -r '.nodes["nix-secrets_2"].locked.rev' sops-host/repo/flake.lock)" = "$(origin_head)" ] || fail "flake.lock was not moved to the pushed nix-secrets"
    [ ! -e sops-host/state/bootstrap/zephy ] || fail "the pending host key outlived a successful install"
    ! grep -q changeme sops-host/log || fail "a sops host was told its password is changeme"

    sops_host
    FAKE_ANYWHERE_EXIT=1 run sops-retry 'hunter2\nhunter2\nABCDEF\ny\n' zephy 10.0.0.9
    [ $status -ne 0 ] || fail "the failing install in the retry case did not fail"
    first_key=$(installed_key)
    [ -e sops-retry/state/bootstrap/zephy/ssh_host_ed25519_key ] || fail "a failed install did not keep its pending host key"
    rm sops-retry/sops-calls sops-retry/flake-calls sops-retry/state/bootstrap/zephy/ssh_host_ed25519_key.pub
    echo "stray" >"$NIX_SECRETS_DIR/untracked.txt"
    echo "unrelated: edit" >>"$NIX_SECRETS_DIR/secret.yaml"
    FAKE_ANYWHERE_EXIT=0 again 'hunter2\nhunter2\nABCDEF\n' zephy 10.0.0.9
    [ $status -eq 0 ] || fail "rerunning after a failed install did not install: $(cat sops-retry/log)"
    [ "$(installed_key)" = "$first_key" ] || fail "the rerun installed a different host key than nix-secrets holds"
    [ "$(registered_key)" = "$first_key" ] || fail "the rerun moved nix-secrets off the pending host key"
    [ "$(secrets_commits)" = 2 ] || fail "the rerun committed to nix-secrets again"
    [ ! -e sops-retry/sops-calls ] || fail "the rerun re-encrypted the secrets again"
    ! grep -q "Push" sops-retry/log || fail "the rerun asked to push again"
    grep -q "Reusing the pending host key" sops-retry/log || fail "the rerun did not say it reused the pending host key"
    [ ! -e sops-retry/flake-calls ] || fail "the rerun updated flake.lock although it already held the pushed nix-secrets"
    [ -n "$($realgit -C "$NIX_SECRETS_DIR" status --porcelain)" ] || fail "the rerun swept unrelated nix-secrets changes into a commit"

    sops_host
    FAKE_SOPS_FAIL=yes run sops-crash 'hunter2\nhunter2\nABCDEF\n' zephy 10.0.0.9
    [ $status -ne 0 ] && grep -q "sops updatekeys failed" sops-crash/log || fail "a failing re-encrypt did not stop the install"
    [ "$(secrets_commits)" = 1 ] || fail "a failing re-encrypt still committed"
    echo "note: mine" >"$NIX_SECRETS_DIR/notes.yaml" && $realgit -C "$NIX_SECRETS_DIR" add notes.yaml && $realgit -C "$NIX_SECRETS_DIR" commit -qm notes
    echo "note: edited" >"$NIX_SECRETS_DIR/notes.yaml"
    echo "staged: mine" >"$NIX_SECRETS_DIR/staged.yaml" && $realgit -C "$NIX_SECRETS_DIR" add staged.yaml
    again 'hunter2\nhunter2\nABCDEF\ny\n' zephy 10.0.0.9
    [ $status -eq 0 ] || fail "rerunning after a cut-short re-encrypt did not install: $(cat sops-crash/log)"
    [ "$(secrets_commits)" = 3 ] && [ "$(registered_key)" = "$(installed_key)" ] || fail "the rerun did not finish the cut-short re-encrypt into one commit for the installed key"
    ! $realgit -C "$NIX_SECRETS_DIR" diff --quiet HEAD -- notes.yaml || fail "the rerun swept an unrelated nix-secrets edit into the host key commit"
    ! $realgit -C "$NIX_SECRETS_DIR" show --name-only --format= HEAD | grep -q staged.yaml || fail "the rerun committed a file that was staged in nix-secrets beforehand"

    sops_host
    setup sops-no-upstream
    $realgit -C "$NIX_SECRETS_DIR" branch -q --unset-upstream
    again 'hunter2\nhunter2\nABCDEF\ny\n' zephy 10.0.0.9
    [ $status -ne 0 ] && grep -q "no upstream" sops-no-upstream/log || fail "a nix-secrets branch without an upstream was not explained: $(cat sops-no-upstream/log)"
    [ ! -e sops-no-upstream/anywhere-args ] || fail "nixos-anywhere ran with nix-secrets unpushed"

    sops_host
    FAKE_LOCK_REV=0000000000000000000000000000000000000000 run sops-stale-lock 'hunter2\nhunter2\nABCDEF\ny\n' zephy 10.0.0.9
    [ $status -ne 0 ] && grep -q "not the pushed" sops-stale-lock/log || fail "a flake.lock left off the pushed nix-secrets was not refused: $(cat sops-stale-lock/log)"
    [ ! -e sops-stale-lock/anywhere-args ] || fail "nixos-anywhere ran with flake.lock off the pushed nix-secrets"

    sops_host
    setup sops-nothing-encrypted
    printf 'data: plain\n' >"$NIX_SECRETS_DIR/secret.yaml"
    $realgit -C "$NIX_SECRETS_DIR" commit -qam "no secrets"
    again 'hunter2\nhunter2\nABCDEF\ny\n' zephy 10.0.0.9
    [ $status -ne 0 ] && grep -q "Found no sops-encrypted files" sops-nothing-encrypted/log || fail "re-encrypting no files was not refused"
    [ "$(secrets_commits)" = 2 ] || fail "the host key was committed although nothing was re-encrypted"

    sops_host
    run sops-no-push 'hunter2\nhunter2\nABCDEF\nn\n' zephy 10.0.0.9
    [ $status -ne 0 ] || fail "declining the nix-secrets push still installed"
    [ ! -e sops-no-push/anywhere-args ] || fail "nixos-anywhere ran with the new host key unpushed"
    [ "$(origin_head)" != "$(secrets_head)" ] || fail "nix-secrets was pushed after the push was declined"
    again 'hunter2\nhunter2\nABCDEF\ny\n' zephy 10.0.0.9
    [ $status -eq 0 ] || fail "rerunning after declining the push did not install: $(cat sops-no-push/log)"
    [ "$(secrets_commits)" = 2 ] && [ "$(origin_head)" = "$(secrets_head)" ] || fail "the rerun did not push the existing commit, or made another"

    sops_host
    FAKE_OLD_DISK_GONE=yes run disk-replaced '1\nhunter2\nhunter2\nIAL123\ny\n' zephy 10.0.0.9
    [ $status -eq 0 ] || fail "a host whose disk was swapped did not install after picking the new one: $(cat disk-replaced/log)"
    grep -q 'disk = "/dev/disk/by-id/nvme-FAKE_SSD_SERIAL123"' disk-replaced/repo/hosts/nixos/zephy/disko.nix || fail "the picked disk did not replace the missing one in the host's files"
    ! grep -q OLD_DISK disk-replaced/repo/hosts/nixos/zephy/disko.nix || fail "the missing disk id is still in the host's files"

    sops_host
    FAKE_SSH_DROP=yes run ssh-drop 'hunter2\nhunter2\nABCDEF\n' zephy 10.0.0.9
    [ $status -ne 0 ] && grep -q "Lost the ssh connection" ssh-drop/log || fail "a dropped ssh connection was not reported: $(cat ssh-drop/log)"
    grep -q OLD_DISK_ABCDEF ssh-drop/repo/hosts/nixos/zephy/disko.nix || fail "a dropped ssh connection was taken as a missing disk and rewrote the host's disk id"
    ! grep -q "pick the disk" ssh-drop/log || fail "a dropped ssh connection offered to pick another disk"

    sops_host
    FAKE_BUILD_FAIL=yes run build-fails "" zephy 10.0.0.9
    [ $status -ne 0 ] && grep -q "Building .#zephy failed" build-fails/log || fail "a failing build did not stop before the prompts: $(cat build-fails/log)"
    ! grep -qE "passphrase|Type the last 6|Push" build-fails/log || fail "a failing build still reached the prompts"
    [ "$(secrets_commits)" = 1 ] || fail "a failing build still rotated the host key"

    sops_host
    setup sops-dirty
    echo unrelated >>"$NIX_SECRETS_DIR/secret.yaml"
    again 'hunter2\nhunter2\nABCDEF\n' zephy 10.0.0.9
    [ $status -ne 0 ] && grep -q "uncommitted changes" sops-dirty/log || fail "uncommitted nix-secrets changes were not refused"
    [ "$(secrets_commits)" = 1 ] || fail "nix-secrets was committed over uncommitted changes"

    touch $out
  ''
