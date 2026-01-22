_: {
  # keyboard settings is not very useful on macOS
  # the most important thing is to remap option key to alt key globally,
  # but it's not supported by macOS yet.
  system.keyboard = {
    enableKeyMapping = true; # enable key mapping so that we can use `option` as `control`

    # NOTE: do NOT support remap capslock to both control and escape at the same time
    remapCapsLockToControl = false; # remap caps lock to control, useful for emac users
    remapCapsLockToEscape = true; # remap caps lock to escape, useful for vim users

    # swap left command and left alt
    # so it matches common keyboard layout: `ctrl | command | alt`
    #
    # disabled, caused only problems!
    swapLeftCommandAndLeftAlt = false;

    userKeyMapping = [
      # remap escape to caps lock
      # so we swap caps lock and escape, then we can use caps lock as escape
      {
        # HIDKeyboardModifierMappingSrc = 30064771113;
        # HIDKeyboardModifierMappingDst = 30064771129;
      }
    ];
  };
}
