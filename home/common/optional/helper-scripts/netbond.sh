#!/usr/bin/env bash
# netbond — bond every physical internet uplink (Wi-Fi + any USB-tethered
# phones) into one per-flow load-balanced default route, and mint extra Wi-Fi
# "devices" on a single radio to beat per-device (per-MAC) captive/hotel caps.
# Auto-detects uplinks; no hardcoded addresses.
#
#   netbond up              discover all uplinks and balance across them
#   netbond down            tear down, restore a normal single default
#   netbond status          show the current bond
#   netbond test            parallel downloads, report bytes carried per uplink
#   netbond wifi-add [SSID] [PASS]
#                            add a 2nd+ Wi-Fi station (fresh MAC) on this radio,
#                            connect, walk through its captive portal, rebond.
#                            PASS is the WPA/WPA2/WPA3 passphrase; omit it for an
#                            open network, or to reuse a passphrase already saved
#                            for this SSID (or be prompted for it).
#   netbond wifi-del <if>    remove a station added by wifi-add (or: all)
#   netbond portal <if>      (re)run the captive-portal login for an interface
#
# Per-flow: a single stream stays on one link; many connections spread out.
# NOTE: extra Wi-Fi stations share the one radio's airtime — they add a per-
# device *data* allowance, not extra *speed*. Privileged steps escalate via
# sudo automatically.

TABLE_BASE=100 # routing tables 100..100+N-1, one per uplink
RULE_BASE=100  # ip-rule priorities, same range
TABLE_MAX=163  # cleanup / status scan this far
PROTO=static   # tag our default route so teardown targets only it
VIF_PREFIX=nbwlan
PORTAL_CHECK="http://connectivitycheck.gstatic.com/generate_204"
# interfaces that are never real uplinks (VPNs, bridges, virtual, loopback)
VIRT_RE='^(lo|tun|tap|wg|tailscale|docker|br-|veth|virbr|zt|ppp|p2p|nebula|gpd|utun)'

run_priv() { if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo -- "$@"; fi; }

# Emit one TAB-separated "dev gw src net" line per physical uplink.
discover() {
  # shellcheck disable=SC2016  # $re is a jq variable, not shell
  ip -j route show default | jq -r --arg re "$VIRT_RE" '
      .[] | select(.dev and .gateway)
      | select(.dev | test($re) | not)
      | "\(.dev)\t\(.gateway)\t\(.prefsrc // "")"' |
    sort -u |
    while IFS=$'\t' read -r dev gw src; do
      [ -n "$src" ] || src=$(ip -j -4 addr show dev "$dev" |
        jq -r 'first(.[].addr_info[]? | select(.scope=="global") | .local) // empty')
      [ -n "$src" ] || continue
      net=$(ip -o route show dev "$dev" proto kernel scope link | awk '{print $1; exit}')
      [ -n "$net" ] || continue
      printf '%s\t%s\t%s\t%s\n' "$dev" "$gw" "$src" "$net"
    done
}

iface_ip() {
  ip -j -4 addr show dev "$1" 2>/dev/null |
    jq -r 'first(.[].addr_info[]? | select(.scope=="global") | .local) // empty'
}

# All Wi-Fi netdevs on this host (one line each).
wifi_ifaces() {
  local p
  for p in /sys/class/net/*/phy80211; do
    [ -e "$p" ] || continue
    basename "$(dirname "$p")"
  done
}

# Secondary stations: every Wi-Fi netdev that ISN'T its radio's primary. The
# primary is the interface the driver created at boot, i.e. the lowest ifindex
# on that phy; VIFs added later have higher ifindices. So the built-in Wi-Fi is
# never listed and `wifi-del all` can't nuke it — even if its MAC is randomized.
extra_stations() {
  local p dev phy idx
  local -A primidx=() primdev=()
  for p in /sys/class/net/*/phy80211; do
    [ -e "$p" ] || continue
    dev=$(basename "$(dirname "$p")")
    phy=$(cat "$p/name")
    idx=$(cat "/sys/class/net/$dev/ifindex")
    if [ -z "${primidx[$phy]:-}" ] || [ "$idx" -lt "${primidx[$phy]}" ]; then
      primidx[$phy]=$idx
      primdev[$phy]=$dev
    fi
  done
  for p in /sys/class/net/*/phy80211; do
    [ -e "$p" ] || continue
    dev=$(basename "$(dirname "$p")")
    phy=$(cat "$p/name")
    [ "$dev" = "${primdev[$phy]:-}" ] || echo "$dev"
  done
}

_clean() {
  local t
  for ((t = TABLE_BASE; t <= TABLE_MAX; t++)); do
    while run_priv ip rule del table "$t" 2>/dev/null; do :; done
    run_priv ip route flush table "$t" 2>/dev/null || true
  done
  run_priv ip route del default proto "$PROTO" 2>/dev/null || true
  run_priv ip route flush cache 2>/dev/null || true
}

up() {
  _clean
  local -a links
  mapfile -t links < <(discover)
  [ "${#links[@]}" -ge 1 ] || {
    echo "netbond: no physical uplinks found" >&2
    exit 1
  }

  local idx=0 dev gw src net t prio l
  local -a nexthops=() devs=()
  for l in "${links[@]}"; do
    IFS=$'\t' read -r dev gw src net <<<"$l"
    t=$((TABLE_BASE + idx))
    prio=$((RULE_BASE + idx))
    run_priv ip route add "$net" dev "$dev" src "$src" table "$t"
    run_priv ip route add default via "$gw" dev "$dev" table "$t"
    run_priv ip rule add from "$src" table "$t" priority "$prio"
    nexthops+=(nexthop via "$gw" dev "$dev" weight 1)
    devs+=("$dev")
    printf '  + %-16s via %-15s src %s\n' "$dev" "$gw" "$src"
    idx=$((idx + 1))
  done

  run_priv ip route replace default scope global proto "$PROTO" "${nexthops[@]}"

  run_priv sysctl -qw net.ipv4.fib_multipath_hash_policy=1 # hash by full flow
  run_priv sysctl -qw net.ipv4.conf.all.rp_filter=2        # loose RPF
  for dev in "${devs[@]}"; do
    run_priv sysctl -qw "net.ipv4.conf.$dev.rp_filter=2"
    # ARP hygiene so uplinks sharing a subnet don't answer for each other
    run_priv sysctl -qw "net.ipv4.conf.$dev.arp_ignore=1"
    run_priv sysctl -qw "net.ipv4.conf.$dev.arp_announce=2"
  done

  echo "netbond: bonded ${#links[@]} uplink(s)"
}

down() {
  _clean
  echo "netbond: torn down (DHCP defaults restored)"
}

status() {
  echo "== default route =="
  ip route show default
  echo
  echo "== source rules =="
  ip rule show | grep -E "lookup ($(seq -s'|' "$TABLE_BASE" "$TABLE_MAX"))" || echo "  (none)"
  echo
  echo "== Wi-Fi stations (extra = secondary on one radio, removable) =="
  local d conn kind
  local -a extras
  mapfile -t extras < <(extra_stations)
  for d in $(wifi_ifaces); do
    conn=$(nmcli -g GENERAL.CONNECTION device show "$d" 2>/dev/null || true)
    kind=primary
    printf '%s\n' "${extras[@]}" | grep -qx "$d" && kind=extra
    printf '  %-10s %-8s conn=%s\n' "$d" "$kind" "${conn:-none}"
  done
}

# Walk an interface through its captive portal: route via it, open the portal in
# the user's browser, poll until the network stops intercepting. Returns 0 once
# the interface has clear internet.
portal() {
  local vif=$1
  [ -n "$vif" ] || {
    echo "usage: netbond portal <if>" >&2
    exit 1
  }
  local gw src code url resp
  src=$(iface_ip "$vif")
  gw=$(ip -j route show default dev "$vif" | jq -r 'first(.[].gateway) // empty')
  [ -n "$src" ] && [ -n "$gw" ] || {
    echo "netbond: $vif has no IP/gateway yet" >&2
    exit 1
  }

  resp=$(curl -s --interface "$vif" --max-time 8 -o /dev/null \
    -w '%{http_code} %{redirect_url}' "$PORTAL_CHECK" || true)
  code=${resp%% *}
  url=${resp#* }
  if [ "$code" = "204" ]; then
    echo "netbond: $vif already online (no portal)"
    return 0
  fi
  [ -n "$url" ] || url=$PORTAL_CHECK
  echo "netbond: $vif is behind a captive portal — routing browser via $vif"

  # Force traffic (incl. the browser) out this interface so the portal binds to
  # ITS mac. Rebonded afterwards by the caller (wifi-add) or `netbond up`.
  run_priv ip route replace default via "$gw" dev "$vif" src "$src" proto "$PROTO"

  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 &
  else
    echo "  open this in a browser and log in: $url"
  fi

  echo -n "  waiting for you to accept the portal"
  for _ in $(seq 1 60); do
    code=$(curl -s --interface "$vif" --max-time 6 -o /dev/null \
      -w '%{http_code}' "$PORTAL_CHECK" || true)
    if [ "$code" = "204" ]; then
      echo " — online!"
      return 0
    fi
    echo -n "."
    sleep 2
  done
  echo " — timed out (still captive)"
  return 1
}

# Echo "PSK<TAB>KEYMGMT" from the first saved NM profile matching this SSID, so
# joining a network you already have credentials for needs no re-typing. Skips
# our own netbond-* profiles (they may be passwordless). Reading the secret
# needs privilege, hence run_priv.
saved_wifi_secret() {
  local ssid=$1 c cssid psk keymgmt
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    cssid=$(nmcli -g 802-11-wireless.ssid connection show "$c" 2>/dev/null || true)
    [ "$cssid" = "$ssid" ] || continue
    psk=$(run_priv nmcli -s -g 802-11-wireless-security.psk connection show "$c" 2>/dev/null || true)
    keymgmt=$(nmcli -g 802-11-wireless-security.key-mgmt connection show "$c" 2>/dev/null || true)
    [ -n "$psk" ] || continue
    printf '%s\t%s\n' "$psk" "$keymgmt"
    return 0
  done < <(nmcli -t -f NAME,TYPE connection show 2>/dev/null |
    awk -F: '$2=="802-11-wireless" && $1 !~ /^netbond-/{print $1}')
}

wifi_add() {
  local ssid=$1 pass=${2-} phy vif mac ip n keymgmt secret
  phy=$(find /sys/class/ieee80211 -maxdepth 1 -mindepth 1 -printf '%f\n' 2>/dev/null | head -1)
  [ -n "$phy" ] || {
    echo "netbond: no Wi-Fi radio found" >&2
    exit 1
  }
  if [ -z "$ssid" ]; then
    ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null |
      awk -F: '$1=="yes"{print substr($0, index($0,":")+1)}' | head -1)
  fi
  [ -n "$ssid" ] || {
    echo "netbond: no SSID given and none active; pass one: netbond wifi-add <SSID>" >&2
    exit 1
  }

  # Resolve a passphrase: explicit arg > saved NM profile for this SSID > prompt.
  # An empty passphrase means an open network (key-mgmt stays unset).
  keymgmt=""
  if [ -n "$pass" ]; then
    keymgmt=wpa-psk
  elif secret=$(saved_wifi_secret "$ssid") && [ -n "$secret" ]; then
    pass=${secret%%$'\t'*}
    keymgmt=${secret#*$'\t'}
    [ -n "$keymgmt" ] || keymgmt=wpa-psk
    echo "netbond: reusing saved passphrase for \"$ssid\""
  else
    read -rsp "  passphrase for \"$ssid\" (blank = open network): " pass </dev/tty || true
    echo
    [ -z "$pass" ] || keymgmt=wpa-psk
  fi

  n=0
  while ip link show "${VIF_PREFIX}${n}" >/dev/null 2>&1; do n=$((n + 1)); done
  vif="${VIF_PREFIX}${n}"
  mac=$(printf '02:%02x:%02x:%02x:%02x:%02x' \
    "$((RANDOM % 256))" "$((RANDOM % 256))" "$((RANDOM % 256))" \
    "$((RANDOM % 256))" "$((RANDOM % 256))")

  # iwlwifi radios usually cap at 2 concurrent stations (managed <= 2). If the
  # primary + existing extras already fill that, a new one comes up
  # "unavailable" and never gets a lease.
  local nsta p
  nsta=0
  for p in /sys/class/net/*/phy80211; do
    [ -e "$p" ] && [ "$(cat "$p/name")" = "$phy" ] && nsta=$((nsta + 1))
  done
  if [ "$nsta" -ge 2 ]; then
    echo "netbond: $phy already has $nsta stations; radio usually caps at 2." >&2
    echo "         run 'netbond wifi-del all' first or the new one will be 'unavailable'." >&2
  fi

  echo "netbond: adding station $vif (mac $mac) on $phy -> \"$ssid\""
  run_priv iw phy "$phy" interface add "$vif" type managed
  run_priv ip link set "$vif" address "$mac" # spoof MAC = a distinct device
  run_priv ip link set "$vif" up             # bring up so NM/wpa_supplicant registers it
  sleep 2                                    # let NM move it from 'unavailable' to available
  run_priv nmcli device set "$vif" managed yes 2>/dev/null || true

  local -a secargs=()
  [ -n "$keymgmt" ] && secargs=(wifi-sec.key-mgmt "$keymgmt" wifi-sec.psk "$pass")
  run_priv nmcli connection add type wifi ifname "$vif" \
    con-name "netbond-$vif" ssid "$ssid" "${secargs[@]}" >/dev/null

  # The fresh VIF hasn't scanned yet, so the first activation often fails with
  # "network could not be found". Rescan and retry a few times.
  for _ in 1 2 3; do
    run_priv nmcli connection up "netbond-$vif" >/dev/null 2>&1 && break
    run_priv nmcli device wifi rescan ifname "$vif" >/dev/null 2>&1 || true
    sleep 3
  done

  echo -n "  waiting for DHCP lease"
  for _ in $(seq 1 20); do
    ip=$(iface_ip "$vif")
    [ -n "$ip" ] && break
    echo -n "."
    sleep 1
  done
  echo
  [ -n "$ip" ] || {
    echo "netbond: $vif got no lease — wrong passphrase, SSID out of range, or the radio can't hold a 2nd station here" >&2
    exit 1
  }
  echo "  $vif up with $ip"

  portal "$vif" || echo "netbond: portal not completed; $vif joins the bond but has no internet yet"
  echo "netbond: rebonding to include $vif ..."
  up
}

wifi_del() {
  local target=$1
  [ -n "$target" ] || {
    echo "usage: netbond wifi-del <if|all>" >&2
    echo "  'all' removes every secondary station; run 'netbond status' to list them." >&2
    exit 1
  }
  local -a vifs
  if [ "$target" = "all" ]; then
    mapfile -t vifs < <(extra_stations)
    [ "${#vifs[@]}" -gt 0 ] || {
      echo "netbond: no secondary stations to remove"
      return 0
    }
  else
    vifs=("$target")
  fi
  local vif conn
  for vif in "${vifs[@]}"; do
    # delete whatever NM profile is bound to it (hotel2, netbond-*, anything)
    conn=$(nmcli -g GENERAL.CONNECTION device show "$vif" 2>/dev/null || true)
    [ -n "$conn" ] && run_priv nmcli connection delete "$conn" >/dev/null 2>&1 || true
    run_priv nmcli connection delete "netbond-$vif" >/dev/null 2>&1 || true
    run_priv iw dev "$vif" del 2>/dev/null || true
    echo "netbond: removed $vif${conn:+ (connection \"$conn\")}"
  done
}

test_bond() {
  local url="https://speed.cloudflare.com/__down?bytes=25000000"
  local -a devs
  mapfile -t devs < <(discover | cut -f1)
  [ "${#devs[@]}" -ge 1 ] || {
    echo "netbond: no uplinks" >&2
    exit 1
  }
  read_rx() { awk -v i="$1" '$0 ~ i":"{gsub(/.*:/,"");print $1}' /proc/net/dev; }
  local d
  local -A rx0
  for d in "${devs[@]}"; do rx0[$d]=$(read_rx "$d"); done
  echo "firing 12 parallel downloads across ${#devs[@]} uplink(s)..."
  for _ in $(seq 1 12); do curl -s --max-time 35 -o /dev/null "$url" & done
  wait
  for d in "${devs[@]}"; do
    printf '  %-16s %5d MB\n' "$d" "$((($(read_rx "$d") - rx0[$d]) / 1024 / 1024))"
  done
}

case "${1:-}" in
up) up ;;
down) down ;;
status) status ;;
test)
  shift
  test_bond "$@"
  ;;
wifi-add)
  shift
  wifi_add "$@"
  ;;
wifi-del)
  shift
  wifi_del "$@"
  ;;
portal)
  shift
  portal "$@"
  ;;
*)
  echo "usage: netbond {up|down|status|test|wifi-add [SSID]|wifi-del <if|all>|portal <if>}" >&2
  exit 1
  ;;
esac
