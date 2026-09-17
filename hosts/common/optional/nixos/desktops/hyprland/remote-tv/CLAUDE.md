# remote-tv — debugging Miracast

GNOME Network Displays (GND) patched for two sinks: a Samsung `UN65RU740D`
(`[TV] Adds tv`, Wi-Fi Direct) and an LG webOS panel (`Big Ben`, MICE). Every
patch here exists because of a measured failure — the header of each records the
evidence. Read the header before changing one.

## Two transports, almost nothing shared

| | Wi-Fi Direct (P2P) | MICE (infrastructure) |
|---|---|---|
| Discovery | wpa_supplicant P2P peers via NM | mDNS `_display._tcp`, port 7250 |
| Sink example | Samsung `[TV] Adds tv` | LG `Big Ben` |
| Transport | `p2p-wl+` group interface | the ordinary LAN |
| Firewall | `trustedInterfaces` covers it | needs `allowedTCPPorts = [7236]` |

RTSP is 7236 either way. MICE has the source listen on 7236 and the **sink dial
back in**, which is why trusting the P2P interface is not enough — a MICE cast
fails silently with the port closed, because `logRefusedConnections` is false and
the drop is never logged.

## Test loop (no rebuild)

`nixos-rebuild` is far too slow to iterate with. Build the patched package
straight from the repo patches and run it from the store:

```nix
# gnd-live.nix
let
  f = builtins.getFlake "path:/home/addg/nix-config";
  pkgs = f.inputs.nixpkgs.legacyPackages.x86_64-linux;
in pkgs.gnome-network-displays.overrideAttrs (old: {
  patches = (old.patches or []) ++ [ ./gnd-keepalive-quirk.patch /* … */ ];
})
```

```sh
nix build --impure --no-link --print-out-paths --file gnd-live.nix
```

Patch paths must be **path literals**, not strings — a string is not copied into
the store and the builder dies with "No such file or directory".

GND is a GUI app, so it needs the session environment. Take it from the running
process (`tr '\0' '\n' < /proc/<pid>/environ`) or rebuild it: `XDG_RUNTIME_DIR`,
`WAYLAND_DISPLAY`, `XDG_CURRENT_DESKTOP=Hyprland`, `HYPRLAND_INSTANCE_SIGNATURE`,
`DBUS_SESSION_BUS_ADDRESS`. Also `unset LIBVA_DRIVER_NAME` — the system package
gets that from a `symlinkJoin` wrapper that a raw store path does not have, and
`nvidia` is decode-only, so `vah264enc` never registers and GND silently drops to
software x264enc.

Launch detached with `setsid … &`, redirecting to a log. GND launched from the
desktop runs under a uwsm scope and its stderr goes nowhere, so a normally
started instance is undebuggable.

Useful env levers, all runtime, no rebuild:

- `GND_FORCE_RESOLUTION=WxH@R` / `GND_FALLBACK_RESOLUTION`
- `GND_KEEPALIVE=none` — do not ping at all
- `GND_FORCE_PROFILE=base`, `GND_COLOR_RANGE=full`
- `G_MESSAGES_DEBUG=all`, `GST_DEBUG=2,rtspclient:5`

## Reading a session

```
ND_SINK_STATE_WAIT_SOCKET → WAIT_STREAMING → STREAMING
"Client connection removed" → DISCONNECTED     ← the sink hung up
```

Time `STREAMING` to `Client connection removed`. A repeatable duration is a
timeout, not a crash, and the number identifies it: ~35s was the LG closing an
unpinged session; 25s gaps between `Doing keep-alive` are our pings.

## Traps that produce false negatives

Each of these was believed once and was wrong.

- `strings` is absent on some hosts; `strings | grep -q` then reports every patch
  as missing. Use `grep -a` on the binary.
- The real ELF is `bin/.gnome-network-displays-wrapped`; `bin/<name>` is a
  compiled `makeBinaryWrapper` stub with none of the source strings. `ls -1`
  hides it.
- `CTRL-EVENT-SCAN-STARTED` is absent from the journal even on a host where
  discovery works. It never means the radio is idle.
- `nmcli general logging` needs root. Without it the level silently stays `WARN`
  and NetworkManager emits nothing, which reads as "NM is doing nothing".
- `pkill -f <pattern>` matches the calling shell, because the pattern text is in
  its argv. Collect pids and skip `$$`/`$PPID`.
- A once-only `g_debug` at startup proves nothing if debug logging was enabled
  later.
- Do not `udevadm test` a live network device: it *executes* `RUN` commands and
  will restart wpa_supplicant, dropping wifi.
- Never `GetAll` a wpa_supplicant `Peer` object over D-Bus. It aborts the daemon
  in `wpas_dbus_getter_p2p_peer_groups` and takes wifi with it. Reading the
  interface's `P2PDevice.Peers` list is safe.

## Where each layer can be inspected

- GND's own view: the log, `G_MESSAGES_DEBUG=all`.
- NetworkManager's peers, no root: `busctl --system get-property
  org.freedesktop.NetworkManager <device> …Device.WifiP2P Peers`, then `Name` /
  `HwAddress` / `WfdIEs` per peer. Empty properties mean the peer was learned
  from a beacon, never a probe exchange.
- Capture fidelity: `grim -c -o <output>` uses the same compositor path. Compare
  the pointer against `hyprctl cursorpos` after undoing the monitor's layout
  offset and scale before blaming the pipeline.

## Known-unfixed

- `demon` (mt7925e) discovers no Miracast sink: the driver never performs P2P
  active search, so only continuously-beaconing group owners are ever seen. The
  whole stack there is otherwise identical to freya's.
- An arrow appears top-left of the Samsung stream, absent from the local
  framebuffer. Ruled out: the `microsoft_cursor` extension, the encoder profile,
  and the capture itself. Untested: whether it shows in GND's own preview, which
  separates a pipeline cause from a sink-side overlay.
