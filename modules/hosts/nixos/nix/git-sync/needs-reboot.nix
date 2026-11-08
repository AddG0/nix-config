# Exits 0 when system $1 changes what only a reboot activates (kernel, initrd, kernel modules), 1 when switch can apply it.
{
  writeShellApplication,
  coreutils,
}:
writeShellApplication {
  name = "nix-remote-rebuild-needs-reboot";
  runtimeInputs = [coreutils];
  text = ''
    if [ $# -ne 1 ]; then
      echo "usage: nix-remote-rebuild-needs-reboot <system>" >&2
      exit 2
    fi
    booted=''${BOOTED_SYSTEM:-/run/booted-system}

    for part in kernel initrd kernel-modules; do
      if [ "$(readlink -f "$booted/$part")" != "$(readlink -f "$1/$part")" ]; then
        echo "The $part differs from the booted system's."
        exit 0
      fi
    done
    exit 1
  '';
}
