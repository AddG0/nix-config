# just bootstrap: what it writes, what it refuses, what it hands nixos-anywhere, and what a rerun skips, against a stubbed stick.
{
  harness,
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
      *disko.devices.disk.main.content.partitions)
        grep -q luks-btrfs "$REPO/hosts/nixos/$HOST/disko.nix" && echo "[\"$FAKE_PASSWORD_FILE\"]" || echo '[]' ;;
      *disko.devices.disk.main.device) sed -n 's/.*disk = "\(.*\)";/\1/p' "$REPO/hosts/nixos/$HOST/disko.nix" ;;
      *boot.initrd.luks.devices) echo '["crypted"]' ;;
      *sops.age.sshKeyPaths) echo /persist/etc/ssh/ssh_host_ed25519_key ;;
      *hostSpec.primaryUsername) echo tester ;;
      *) echo "nix stub: unexpected $*" >&2; exit 1 ;;
    esac
  '';
in
  harness.bats "bootstrap-nixos" [./bootstrap.bats] {
    nativeBuildInputs = [ssh git nix sops pkgs.jq pkgs.openssh pkgs.ssh-to-age pkgs.yq-go];
    bootstrapDir = "${self}/scripts/bootstrap";
    helpers = "${self}/scripts/helpers.sh";
    realgit = "${pkgs.git}/bin/git";
  }
