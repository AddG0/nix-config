# hypridle resolves its logind session once at startup with GetSession("auto")
# and pins its Lock/Unlock dbus match to that path for the life of the process.
# A session-less user@.service caller resolves to logind's *elected display
# session*, which is a stray `class=user type=tty` session whenever one outlives
# the graphical session's switch to type=wayland (tty and an unset-type wayland
# session tie at rank -2/-3, and ties keep the incumbent). logind re-elects a
# moment later; hypridle never re-reads, so every lock_cmd silently no-ops until
# the service restarts — screens blank on the dpms listener but never lock.
# Dropping the path filter matches Lock on any session; handleDbusLogin already
# ignores every member except Lock/Unlock.
# CHECK-RUNTIME: fixed upstream when src/core/Hypridle.cpp stops building its addMatch from a GetSession("auto") path.
_: _final: prev: {
  hypridle = prev.hypridle.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace src/core/Hypridle.cpp \
          --replace-fail "\"type='signal',path='\" + path + \"',interface='org.freedesktop.login1.Session'\"" \
            "\"type='signal',interface='org.freedesktop.login1.Session'\""
      '';
  });
}
