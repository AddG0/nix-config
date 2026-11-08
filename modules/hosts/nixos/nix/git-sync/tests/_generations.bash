# Shared by ./rebuild.bats, ./wake.bats and ./needs-reboot.bats: fixture generations $BOOTED_SYSTEM and $BUILT_SYSTEM.

# Makes $BOOTED_SYSTEM a generation of one shared kernel, initrd and module set; cases build $BUILT_SYSTEM.
generations_setup() {
  export BOOTED_SYSTEM=$BATS_TEST_TMPDIR/booted BUILT_SYSTEM=$BATS_TEST_TMPDIR/built
  mkdir -p "$BATS_TEST_TMPDIR/store"
  for part in kernel initrd kernel-modules; do
    touch "$BATS_TEST_TMPDIR/store/$part"
  done
  generation "$BOOTED_SYSTEM"
}

# A generation linking the shared fixture kernel, initrd and modules, except $2 which gets its own.
generation() {
  mkdir -p "$1"
  for part in kernel initrd kernel-modules; do
    if [ "$part" = "${2:-}" ]; then
      touch "$1/$part-new"
      ln -s "$1/$part-new" "$1/$part"
    else
      ln -s "$BATS_TEST_TMPDIR/store/$part" "$1/$part"
    fi
  done
}
