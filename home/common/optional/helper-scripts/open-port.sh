#!/usr/bin/env bash
# Temporarily open a port in the NixOS firewall (IPv4 + IPv6 when available).
# A systemd-run transient timer removes the rule when the duration elapses.
#
# The rule lives only in the runtime nixos-fw chain, so it is dropped by a
# reboot, a firewall restart, or any nixos-rebuild that reloads the firewall --
# while the close timer (a runtime systemd unit) survives. Rule and timer can
# therefore drift apart. To stop that from silently closing the port, every run
# RECONCILES: it verifies the rule is actually present, re-adds it if a reload
# wiped it, and (re)arms the timer. Re-running an already-open port renews it.
#
# For a long-lived opening, declare the port in your NixOS config
# (security.firewall.allowedTCPPorts) instead of this tool.

usage() {
  cat <<EOF
Usage:
  open-port <port> <duration> [tcp|udp]   open (or renew) a port
  open-port --close <port> [tcp|udp]      close a port now
  open-port --status [<port>] [tcp|udp]   show scheduled closes

  port      1-65535
  duration  e.g. 30s, 10m, 1h, 2h30m, 1d
  protocol  tcp (default) or udp

Examples:
  open-port 8080 10m
  open-port 5353 30s udp
  open-port --close 8080
EOF
}

# The chain NixOS's iptables-backend firewall funnels inbound packets through.
FW_CHAIN="nixos-fw"
FW_ACCEPT="nixos-fw-accept"

# True if the given iptables variant has the nixos-fw chain. Absent means the
# firewall is disabled or uses the native nftables backend (networking.nftables
# .enable = true), where iptables writes to a table the firewall never reads.
have_chain() {
  sudo "$1" -w 5 -L "$FW_CHAIN" -n >/dev/null 2>&1
}

rule_present() { # <ipt> <proto> <port>
  sudo "$1" -w 5 -C "$FW_CHAIN" -p "$2" --dport "$3" -j "$FW_ACCEPT" 2>/dev/null
}

# Insert only if absent, so repeated runs never stack duplicate rules.
ensure_rule() { # <ipt> <proto> <port>
  rule_present "$@" || sudo "$1" -w 5 -I "$FW_CHAIN" 1 -p "$2" --dport "$3" -j "$FW_ACCEPT"
}

# Delete every matching rule, not just the first -- guards against duplicates
# left by an earlier buggy run or a partial close.
delete_rules() { # <ipt> <proto> <port>
  while rule_present "$@"; do
    sudo "$1" -w 5 -D "$FW_CHAIN" -p "$2" --dport "$3" -j "$FW_ACCEPT" || break
  done
}

ACTION="open"
case "${1:-}" in
-h | --help)
  usage
  exit 0
  ;;
--status)
  shift
  ACTION="status"
  ;;
--close)
  shift
  ACTION="close"
  ;;
esac

case "$ACTION" in
open)
  if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
    usage
    exit 1
  fi
  PORT="$1"
  DURATION_RAW="$2"
  PROTO="${3:-tcp}"
  ;;
close)
  if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage
    exit 1
  fi
  PORT="$1"
  PROTO="${2:-tcp}"
  ;;
status)
  PORT="${1:-}"
  PROTO="${2:-tcp}"
  ;;
esac

if [ "$ACTION" != "status" ] || [ -n "$PORT" ]; then
  if [ -n "${PORT:-}" ] && { ! [[ $PORT =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; }; then
    echo "Error: invalid port '$PORT' (must be 1-65535)" >&2
    exit 1
  fi
fi

if [ "$PROTO" != "tcp" ] && [ "$PROTO" != "udp" ]; then
  echo "Error: invalid protocol '$PROTO' (must be tcp or udp)" >&2
  exit 1
fi

# Validate the duration before anything that needs sudo, so a typo doesn't
# trigger a password prompt.
if [ "$ACTION" = "open" ]; then
  if ! [[ $DURATION_RAW =~ ^([0-9]+(min|s|m|h|d|w))+$ ]]; then
    echo "Error: invalid duration '$DURATION_RAW'" >&2
    echo "Examples: 30s, 10m, 1h, 2h30m, 1d" >&2
    exit 1
  fi
  # Normalize so '10m' means minutes, not systemd's 'months'.
  DURATION=$(echo "$DURATION_RAW" | sed -E 's/([0-9])m($|[^i])/\1min\2/g')
fi

if [ "$ACTION" = "status" ]; then
  PATTERN="close-port-*.timer"
  [ -n "$PORT" ] && PATTERN="close-port-${PROTO}-${PORT}.timer"
  echo "Scheduled closes:"
  sudo systemctl list-timers --all --no-pager "$PATTERN" 2>/dev/null || true
  exit 0
fi

UNIT="close-port-${PROTO}-${PORT}"

# Fail loudly rather than pretend to open a port the firewall will ignore.
if ! have_chain iptables; then
  echo "Error: '$FW_CHAIN' chain not found." >&2
  echo "The firewall is disabled, or uses the nftables backend (networking.nftables.enable)." >&2
  echo "In the nftables case, open the port with nft, or declare it in security.firewall.allowedTCPPorts." >&2
  exit 1
fi

HAVE_V6=0
have_chain ip6tables && HAVE_V6=1

if [ "$ACTION" = "close" ]; then
  # Stop the timer AND cancel the pending close service, then remove the rule
  # ourselves. (Stopping the timer alone would leave the rule in place forever,
  # since the close service would never fire.)
  sudo systemctl stop "${UNIT}.timer" "${UNIT}.service" >/dev/null 2>&1 || true
  sudo systemctl reset-failed "${UNIT}.timer" "${UNIT}.service" >/dev/null 2>&1 || true

  removed=0
  if rule_present iptables "$PROTO" "$PORT"; then removed=1; fi
  delete_rules iptables "$PROTO" "$PORT"
  [ "$HAVE_V6" = 1 ] && delete_rules ip6tables "$PROTO" "$PORT"

  if [ "$removed" = 1 ]; then
    echo "Closed ${PROTO}/${PORT}."
  else
    echo "${PROTO}/${PORT} was not open; cleared any leftover timer."
  fi
  exit 0
fi

# Detect prior state so we can report accurately and reconcile drift.
TIMER_EXISTS=0
if sudo systemctl list-units --all --no-legend "${UNIT}.timer" 2>/dev/null | grep -q "${UNIT}.timer"; then
  TIMER_EXISTS=1
fi
RULE_EXISTS=0
rule_present iptables "$PROTO" "$PORT" && RULE_EXISTS=1

if [ "$TIMER_EXISTS" = 1 ] && [ "$RULE_EXISTS" = 0 ]; then
  echo "Note: a close timer existed but the rule was gone (firewall reloaded?). Re-adding and renewing." >&2
elif [ "$TIMER_EXISTS" = 1 ]; then
  echo "Renewing existing opening for ${PROTO}/${PORT} to ${DURATION}."
fi

# Clear the old timer/service so systemd-run can reuse the unit name, and clean
# any failed leftovers from an interrupted run.
sudo systemctl stop "${UNIT}.timer" "${UNIT}.service" >/dev/null 2>&1 || true
sudo systemctl reset-failed "${UNIT}.timer" "${UNIT}.service" >/dev/null 2>&1 || true

echo "Opening ${PROTO}/${PORT} for ${DURATION}..."
if ! ensure_rule iptables "$PROTO" "$PORT"; then
  echo "Error: failed to insert IPv4 rule" >&2
  exit 1
fi
if [ "$HAVE_V6" = 1 ]; then
  if ! ensure_rule ip6tables "$PROTO" "$PORT"; then
    echo "Warning: failed to insert IPv6 rule (continuing with IPv4 only)" >&2
    HAVE_V6=0
  fi
fi

rollback() {
  echo "Rolling back firewall rules..." >&2
  delete_rules iptables "$PROTO" "$PORT"
  [ "$HAVE_V6" = 1 ] && delete_rules ip6tables "$PROTO" "$PORT"
}

# The deferred close runs with a minimal PATH and must survive duplicate rules
# (delete-all) and an already-cleared rule (loop exits cleanly). Absolute paths
# because systemd-run transient units don't inherit ours.
IPT_BIN="$(command -v iptables)"
close_snippet() { # <bin>
  printf 'while %s -w 5 -C %s -p %s --dport %s -j %s 2>/dev/null; do %s -w 5 -D %s -p %s --dport %s -j %s; done' \
    "$1" "$FW_CHAIN" "$PROTO" "$PORT" "$FW_ACCEPT" "$1" "$FW_CHAIN" "$PROTO" "$PORT" "$FW_ACCEPT"
}
CLOSE_CMD="$(close_snippet "$IPT_BIN")"
if [ "$HAVE_V6" = 1 ]; then
  CLOSE_CMD="$CLOSE_CMD; $(close_snippet "$(command -v ip6tables)")"
fi
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

NEXT=$(sudo systemctl list-timers --no-pager --no-legend "${UNIT}.timer" 2>/dev/null |
  awk '{print $1, $2, $3}')
SCOPE="v4"
[ "$HAVE_V6" = 1 ] && SCOPE="v4+v6"
echo
echo "Done. ${PROTO}/${PORT} (${SCOPE}) open until: ${NEXT:-$DURATION from now}"
echo "Close now: open-port --close ${PORT} ${PROTO}"
