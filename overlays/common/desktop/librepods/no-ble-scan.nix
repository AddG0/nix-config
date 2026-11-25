# librepods BLE-scans forever while AirPods are disconnected; in a busy room that
# floods D-Bus with bluez updates. We only want status once they connect.
_: _final: prev:
prev.lib.optionalAttrs (prev ? librepods) {
  librepods = prev.librepods.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./patches/no-ble-scan.patch];
  });
}
