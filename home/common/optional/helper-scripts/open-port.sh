#!/usr/bin/env bash
# Temporarily open a port in the NixOS firewall (IPv4 + IPv6 when available).
# A systemd-run transient timer removes the rule when the duration elapses.
# The rule lives only in the runtime nixos-fw chain — it is cleared on reboot,
# firewall restart, or a nixos-rebuild that touches firewall config.

usage() {
	cat <<EOF
Usage: open-port <port> <duration> [tcp|udp]

  port      1-65535
  duration  e.g. 30s, 10m, 1h, 2h30m, 1d
  protocol  tcp (default) or udp

Examples:
  open-port 8080 10m
  open-port 5353 30s udp
  open-port 22 1h
EOF
}

case "${1:-}" in
-h | --help)
	usage
	exit 0
	;;
esac

if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
	usage
	exit 1
fi

PORT="$1"
DURATION_RAW="$2"
PROTO="${3:-tcp}"

if ! [[ $PORT =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
	echo "Error: invalid port '$PORT' (must be 1-65535)" >&2
	exit 1
fi

if [ "$PROTO" != "tcp" ] && [ "$PROTO" != "udp" ]; then
	echo "Error: invalid protocol '$PROTO' (must be tcp or udp)" >&2
	exit 1
fi

# Normalize duration so users can type '10m' without it meaning 10 months.
# Any 'm' immediately after a digit and not followed by 'i' becomes 'min'.
if ! [[ $DURATION_RAW =~ ^([0-9]+(min|s|m|h|d|w))+$ ]]; then
	echo "Error: invalid duration '$DURATION_RAW'" >&2
	echo "Examples: 30s, 10m, 1h, 2h30m, 1d" >&2
	exit 1
fi
DURATION=$(echo "$DURATION_RAW" | sed -E 's/([0-9])m($|[^i])/\1min\2/g')

UNIT="close-port-${PROTO}-${PORT}"

# Detect IPv6 support: chain present in ip6tables
HAVE_V6=0
if sudo ip6tables -L nixos-fw -n >/dev/null 2>&1; then
	HAVE_V6=1
fi

# Clean up any stale failed units from a previous interrupted run.
for u in "${UNIT}.timer" "${UNIT}.service"; do
	if sudo systemctl is-failed --quiet "$u" 2>/dev/null; then
		sudo systemctl reset-failed "$u" >/dev/null 2>&1 || true
	fi
done

# Refuse if an active timer already exists for this port.
if sudo systemctl list-units --all --no-legend "${UNIT}.timer" 2>/dev/null |
	grep -q "${UNIT}.timer"; then
	echo "Port ${PROTO}/${PORT} already has a scheduled close." >&2
	echo "Status:" >&2
	sudo systemctl list-timers "${UNIT}.timer" --no-pager 2>/dev/null || true
	echo >&2
	echo "Cancel with: sudo systemctl stop ${UNIT}.timer" >&2
	exit 1
fi

rollback() {
	echo "Rolling back firewall rules..." >&2
	sudo iptables -D nixos-fw -p "$PROTO" --dport "$PORT" -j nixos-fw-accept 2>/dev/null || true
	if [ "$HAVE_V6" = 1 ]; then
		sudo ip6tables -D nixos-fw -p "$PROTO" --dport "$PORT" -j nixos-fw-accept 2>/dev/null || true
	fi
}

echo "Opening ${PROTO}/${PORT} for ${DURATION}..."
if ! sudo iptables -w 5 -I nixos-fw 1 -p "$PROTO" --dport "$PORT" -j nixos-fw-accept; then
	echo "Error: failed to insert IPv4 rule" >&2
	exit 1
fi

if [ "$HAVE_V6" = 1 ]; then
	if ! sudo ip6tables -w 5 -I nixos-fw 1 -p "$PROTO" --dport "$PORT" -j nixos-fw-accept; then
		echo "Warning: failed to insert IPv6 rule (continuing with IPv4 only)" >&2
		HAVE_V6=0
	fi
fi

# Build the close command. systemd-run transient units don't inherit our PATH,
# so the deferred command needs absolute paths to iptables/ip6tables.
CLOSE_CMD="$(command -v iptables) -w 5 -D nixos-fw -p $PROTO --dport $PORT -j nixos-fw-accept"
if [ "$HAVE_V6" = 1 ]; then
	CLOSE_CMD="$CLOSE_CMD; $(command -v ip6tables) -w 5 -D nixos-fw -p $PROTO --dport $PORT -j nixos-fw-accept"
fi
# Trailing 'true' so the unit exits 0 even if rules were already removed
# (e.g. firewall restarted between open and close).
CLOSE_CMD="$CLOSE_CMD; true"

if ! sudo systemd-run \
	--on-active="$DURATION" \
	--unit="$UNIT" \
	--description="Close ${PROTO}/${PORT} after ${DURATION}" \
	--collect \
	/bin/sh -c "$CLOSE_CMD" >/dev/null; then
	rollback
	echo "Error: failed to schedule close timer" >&2
	exit 1
fi

# Show when it will close.
NEXT=$(sudo systemctl list-timers --no-pager --no-legend "${UNIT}.timer" 2>/dev/null |
	awk '{print $1, $2, $3}')
SCOPE="v4"
[ "$HAVE_V6" = 1 ] && SCOPE="v4+v6"
echo
echo "Done. ${PROTO}/${PORT} (${SCOPE}) open until: ${NEXT:-$DURATION from now}"
echo "Cancel early: sudo systemctl stop ${UNIT}.timer"
