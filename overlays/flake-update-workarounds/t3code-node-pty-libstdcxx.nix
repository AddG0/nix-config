# node-pty 1.2.0-beta ships a prebuilt pty.node with no RPATH to libstdc++, and
# nixpkgs sets dontPatchELF; Node preloads libstdc++ but Electron doesn't, so the
# desktop app's backend dies on startup and no window ever opens.
# CHECK-RUNTIME: launch t3code-desktop; upstream is fixed when
# ~/.t3/userdata/logs/server-child.log shows no NodePtyModuleLoadError without this.
_: _final: prev: {
  t3code = prev.t3code.override {
    t3code-unwrapped = prev.t3code.unwrapped.overrideAttrs (old: {
      postFixup =
        (old.postFixup or "")
        + prev.lib.optionalString prev.stdenv.hostPlatform.isLinux ''
          patchelf --add-rpath ${prev.lib.getLib prev.stdenv.cc.cc}/lib \
            "$out"/libexec/t3code/node_modules/.pnpm/node-pty@*/node_modules/node-pty/prebuilds/linux-${prev.stdenv.hostPlatform.node.arch}/pty.node
        '';
    });
    t3code-resource-monitor = prev.t3code.resourceMonitor;
  };
}
