# librepods forces an AirPods connection by shelling out to `bluetoothctl
# connect` and blocking on `QProcess::waitForFinished()` with no timeout (Qt
# default is 30s). If bluetoothctl doesn't finish in time, the QProcess is
# destroyed while the child is still running, which orphans the bluetoothctl
# process instead of killing it. The orphan holds the device address, so the
# next forced-connect attempt fails immediately and retries — a 30s hang loop
# that repeats forever. Same pattern in the disconnect path.
#
# Fixed by giving waitForFinished a short timeout and killing the child if it
# expires. Upstream: librepods-org/librepods linux/main.cpp connectToAirPods().
_: _final: prev:
prev.lib.optionalAttrs (prev ? librepods) {
  librepods = prev.librepods.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./librepods-bluetoothctl-timeout.patch];
  });
}
