{inputs, ...}: _final: prev:
prev.lib.optionalAttrs prev.stdenv.isLinux {
  # Stop noctalia auto-locking on logind's Lock signal so hyprlock is the sole
  # locker. --replace-fail errors the build if upstream moves this.
  noctalia = inputs.noctalia.packages.${prev.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace src/app/application_ui.cpp \
          --replace-fail '(void)m_lockScreen.lock();' \
            '(void)0; // nix-config: hyprlock owns session locking; noctalia logind auto-lock disabled'

        # Calendar tab hardcodes 24h event times (ignores shell.time_format); force 12h.
        substituteInPlace src/shell/control_center/tabs/calendar_tab.cpp \
          --replace-fail 'formatStrftime("%H:%M", tm)' 'formatStrftime("%I:%M %p", tm)'
      '';
  });
}
