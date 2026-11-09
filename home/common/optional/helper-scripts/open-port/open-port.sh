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
# Each --interface opening has its own close timer, so it never touches an all-interface opening of the same port.
#
# For a long-lived opening, declare the port in your NixOS config
# (networking.firewall.allowedTCPPorts, or .interfaces.<name>) instead of this tool.

usage() {
  cat <<EOF
Usage:
  open-port <port> <duration> [tcp|udp] [-i <interface>]   open (or renew) a port
  open-port --close <port> [tcp|udp] [-i <interface>]      close a port now
  open-port --status [<port>] [tcp|udp] [-i <interface>]   show scheduled closes

  port       1-65535
  duration   e.g. 30s, 10m, 1h, 2h30m, 1d
  protocol   tcp (default) or udp
  interface  -i/--interface: only this interface (tailscale0, or a wildcard like wl+);
             every interface when left out

Examples:
  open-port 8080 10m
  open-port 8080 1h --interface tailscale0
  open-port 5353 30s udp
  open-port --close 8080 --interface tailscale0
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

# The rule's match, set once the arguments are parsed: RULE=([-i <if>] -p <proto> --dport <port> -j <accept>).
RULE=()

rule_present() { # <ipt>
  sudo "$1" -w 5 -C "$FW_CHAIN" "${RULE[@]}" 2>/dev/null
}

# Insert only if absent, so repeated runs never stack duplicate rules.
ensure_rule() { # <ipt>
  rule_present "$1" || sudo "$1" -w 5 -I "$FW_CHAIN" 1 "${RULE[@]}"
}

# Delete every matching rule, not just the first -- guards against duplicates
# left by an earlier buggy run or a partial close.
delete_rules() { # <ipt>
  while rule_present "$1"; do
    sudo "$1" -w 5 -D "$FW_CHAIN" "${RULE[@]}" || break
  done
}

# -i/--interface may come anywhere, so pull it out before reading the positional arguments.
IFACE=""
POSITIONAL=()
while [ "$#" -gt 0 ]; do
  case "$1" in
  -i | --interface)
    if [ "$#" -lt 2 ]; then
      echo "Error: $1 needs an interface name" >&2
      exit 1
    fi
    IFACE="$2"
    shift 2
    ;;
  --interface=*)
    IFACE="${1#--interface=}"
    shift
    ;;
  *)
    POSITIONAL+=("$1")
    shift
    ;;
  esac
done
set -- "${POSITIONAL[@]}"

# At most 15 characters, an iptables wildcard's trailing + included, and never a leading - that reads as an option.
if [ -n "$IFACE" ] && { ! [[ $IFACE =~ ^[A-Za-z0-9_.:][A-Za-z0-9_.:-]*\+?$ ]] || [ "${#IFACE}" -gt 15 ]; }; then
  echo "Error: invalid interface '$IFACE'" >&2
  exit 1
fi

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

# An interface opening gets its own timer; systemd-escape keeps a wildcard's + valid in a unit name.
ON_IFACE=""
IFACE_UNIT=""
if [ -n "$IFACE" ]; then
  ON_IFACE=" on ${IFACE}"
  IFACE_UNIT="-on-$(systemd-escape -- "$IFACE")"
fi

if [ "$ACTION" = "status" ]; then
  PATTERNS=("close-port-*${IFACE_UNIT}.timer")
  if [ -n "$PORT" ] && [ -n "$IFACE" ]; then
    PATTERNS=("close-port-${PROTO}-${PORT}${IFACE_UNIT}.timer")
  elif [ -n "$PORT" ]; then
    PATTERNS=("close-port-${PROTO}-${PORT}.timer" "close-port-${PROTO}-${PORT}-on-*.timer")
  fi
  echo "Scheduled closes:"
  sudo systemctl list-timers --all --no-pager "${PATTERNS[@]}" 2>/dev/null || true
  exit 0
fi

UNIT="close-port-${PROTO}-${PORT}${IFACE_UNIT}"
RULE=(-p "$PROTO" --dport "$PORT" -j "$FW_ACCEPT")
[ -z "$IFACE" ] || RULE=(-i "$IFACE" "${RULE[@]}")

# Fail loudly rather than pretend to open a port the firewall will ignore.
if ! have_chain iptables; then
  echo "Error: '$FW_CHAIN' chain not found." >&2
  echo "The firewall is disabled, or uses the nftables backend (networking.nftables.enable)." >&2
  echo "In the nftables case, open the port with nft, or declare it in networking.firewall.allowedTCPPorts." >&2
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
  if rule_present iptables; then removed=1; fi
  delete_rules iptables
  [ "$HAVE_V6" = 1 ] && delete_rules ip6tables

  if [ "$removed" = 1 ]; then
    echo "Closed ${PROTO}/${PORT}${ON_IFACE}."
  else
    echo "${PROTO}/${PORT}${ON_IFACE} was not open; cleared any leftover timer."
  fi
  exit 0
fi

# Detect prior state so we can report accurately and reconcile drift.
TIMER_EXISTS=0
# -F: a wildcard interface's unit name holds systemd-escape's \x2b, which a regex would misread.
if sudo systemctl list-units --all --no-legend "${UNIT}.timer" 2>/dev/null | grep -qF "${UNIT}.timer"; then
  TIMER_EXISTS=1
fi
RULE_EXISTS=0
rule_present iptables && RULE_EXISTS=1

if [ "$TIMER_EXISTS" = 1 ] && [ "$RULE_EXISTS" = 0 ]; then
  echo "Note: a close timer existed but the rule was gone (firewall reloaded?). Re-adding and renewing." >&2
elif [ "$TIMER_EXISTS" = 1 ]; then
  echo "Renewing existing opening for ${PROTO}/${PORT}${ON_IFACE} to ${DURATION}."
fi

# Clear the old timer/service so systemd-run can reuse the unit name, and clean
# any failed leftovers from an interrupted run.
sudo systemctl stop "${UNIT}.timer" "${UNIT}.service" >/dev/null 2>&1 || true
sudo systemctl reset-failed "${UNIT}.timer" "${UNIT}.service" >/dev/null 2>&1 || true

echo "Opening ${PROTO}/${PORT}${ON_IFACE} for ${DURATION}..."
if ! ensure_rule iptables; then
  echo "Error: failed to insert IPv4 rule" >&2
  exit 1
fi
if [ "$HAVE_V6" = 1 ]; then
  if ! ensure_rule ip6tables; then
    echo "Warning: failed to insert IPv6 rule (continuing with IPv4 only)" >&2
    HAVE_V6=0
  fi
fi

rollback() {
  echo "Rolling back firewall rules..." >&2
  delete_rules iptables
  [ "$HAVE_V6" = 1 ] && delete_rules ip6tables
}

# The deferred close runs with a minimal PATH and must survive duplicate rules
# (delete-all) and an already-cleared rule (loop exits cleanly). Absolute paths
# because systemd-run transient units don't inherit ours.
IPT_BIN="$(command -v iptables)"
close_snippet() { # <bin>
  printf 'while %s -w 5 -C %s %s 2>/dev/null; do %s -w 5 -D %s %s; done' \
    "$1" "$FW_CHAIN" "${RULE[*]}" "$1" "$FW_CHAIN" "${RULE[*]}"
}
CLOSE_CMD="$(close_snippet "$IPT_BIN")"
if [ "$HAVE_V6" = 1 ]; then
  CLOSE_CMD="$CLOSE_CMD; $(close_snippet "$(command -v ip6tables)")"
fi
CLOSE_CMD="$CLOSE_CMD; true"

if ! sudo systemd-run \
  --on-active="$DURATION" \
  --unit="$UNIT" \
  --description="Close ${PROTO}/${PORT}${ON_IFACE} after ${DURATION}" \
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
echo "Done. ${PROTO}/${PORT}${ON_IFACE} (${SCOPE}) open until: ${NEXT:-$DURATION from now}"
echo "Close now: open-port --close ${PORT} ${PROTO}${IFACE:+ --interface ${IFACE}}"
