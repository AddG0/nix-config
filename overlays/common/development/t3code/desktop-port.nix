# The desktop app's own port. postFixup of `unwrapped`: see README.md.
_: _final: prev: let
  # The app forks its own backend instead of attaching to a running one, so it
  # needs a port of its own; 3773 stays with the server unit (home
  # .../development/ai/t3code/server.nix).
  desktopPort = 3774;
in {
  t3code = prev.t3code.override {
    t3code-unwrapped = prev.t3code.unwrapped.overrideAttrs (old: {
      postFixup =
        (old.postFixup or "")
        + ''
          wrapProgram "$out/bin/t3code-desktop" \
            --set-default T3CODE_PORT ${toString desktopPort}
        '';
    });
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = prev.t3code.resourceMonitor;
  };
}
