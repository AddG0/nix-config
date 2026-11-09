# open-port against a fake firewall: the rule each opening adds, on which interface, and what its close timer removes.
# Fakes keep nixos-fw's rules in $IPTABLES_STATE.iptables and .ip6tables, and the armed close timers in $SYSTEMD_STATE.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  export IPTABLES_STATE=$BATS_TEST_TMPDIR/rules SYSTEMD_STATE=$BATS_TEST_TMPDIR/timers SUDO_LOG=$BATS_TEST_TMPDIR/sudo.log
  : >"$SUDO_LOG"
}

rules() { # <iptables|ip6tables>
  cat "$IPTABLES_STATE.$1" 2>/dev/null
}

timers() {
  cat "$SYSTEMD_STATE" 2>/dev/null
}

# Runs what the named close timer runs when it fires.
fire() { # <unit>
  sh -c "$(cat "$SYSTEMD_STATE.$1.command")"
}

@test "opens a port on every interface, IPv4 and IPv6, until its close timer fires" {
  run "$openPort" 8080 10m
  assert_success
  assert_equal "$(rules iptables)" "-p tcp --dport 8080 -j nixos-fw-accept"
  assert_equal "$(rules ip6tables)" "-p tcp --dport 8080 -j nixos-fw-accept"
  assert_equal "$(cat "$SYSTEMD_STATE.close-port-tcp-8080.after")" "10min"
  fire close-port-tcp-8080
  assert_equal "$(rules iptables)" ""
  assert_equal "$(rules ip6tables)" ""
}

@test "opens a port on one interface only, until its close timer fires" {
  run "$openPort" 8080 1h --interface tailscale0
  assert_success
  assert_output --partial "Opening tcp/8080 on tailscale0 for 1h..."
  assert_equal "$(rules iptables)" "-i tailscale0 -p tcp --dport 8080 -j nixos-fw-accept"
  assert_equal "$(rules ip6tables)" "-i tailscale0 -p tcp --dport 8080 -j nixos-fw-accept"
  fire close-port-tcp-8080-on-tailscale0
  assert_equal "$(rules iptables)" ""
  assert_equal "$(rules ip6tables)" ""
}

@test "takes the interface before the port, as an iptables wildcard" {
  run "$openPort" -i wl+ 5353 30s udp
  assert_success
  assert_equal "$(rules iptables)" "-i wl+ -p udp --dport 5353 -j nixos-fw-accept"
  assert_equal "$(timers)" 'close-port-udp-5353-on-wl\x2b.timer'
}

@test "renews a wildcard-interface opening, finding its escaped timer" {
  "$openPort" -i wl+ 5353 30s udp >/dev/null
  run "$openPort" -i wl+ 5353 1h udp
  assert_success
  assert_output --partial "Renewing existing opening for udp/5353 on wl+ to 1h."
  assert_equal "$(rules iptables)" "-i wl+ -p udp --dport 5353 -j nixos-fw-accept"
  assert_equal "$(timers)" 'close-port-udp-5353-on-wl\x2b.timer'
}

@test "keeps an interface opening apart from an all-interface opening of the same port" {
  "$openPort" 8080 1h >/dev/null
  "$openPort" 8080 1h --interface tailscale0 >/dev/null
  run "$openPort" --close 8080 --interface tailscale0
  assert_success
  assert_output "Closed tcp/8080 on tailscale0."
  assert_equal "$(rules iptables)" "-p tcp --dport 8080 -j nixos-fw-accept"
  assert_equal "$(timers)" "close-port-tcp-8080.timer"
}

@test "lists a port's openings on every interface and on one" {
  "$openPort" 8080 1h >/dev/null
  "$openPort" 8080 1h --interface tailscale0 >/dev/null
  run "$openPort" --status 8080
  assert_success
  assert_output --partial "close-port-tcp-8080.timer"
  assert_output --partial "close-port-tcp-8080-on-tailscale0.timer"
}

@test "lists only one interface's openings when asked for that interface" {
  "$openPort" 8080 1h >/dev/null
  "$openPort" 8080 1h --interface tailscale0 >/dev/null
  "$openPort" 5353 1h udp --interface=wl+ >/dev/null
  run "$openPort" --status --interface wl+
  assert_success
  assert_output --partial 'close-port-udp-5353-on-wl\x2b.timer'
  refute_output --partial "close-port-tcp-8080"
}

@test "re-adds an interface rule a firewall reload wiped while its close timer was still armed" {
  "$openPort" 8080 1h --interface tailscale0 >/dev/null
  : >"$IPTABLES_STATE.iptables"
  run "$openPort" 8080 1h --interface tailscale0
  assert_success
  assert_output --partial "the rule was gone (firewall reloaded?)"
  assert_equal "$(rules iptables)" "-i tailscale0 -p tcp --dport 8080 -j nixos-fw-accept"
}

@test "rejects an interface name no Linux interface can have, before asking sudo for anything" {
  run "$openPort" 8080 1h --interface 'eth0;reboot'
  assert_failure 1
  assert_output --partial "invalid interface 'eth0;reboot'"
  assert_equal "$(cat "$SUDO_LOG")" ""
}

@test "rejects an interface name that would read as an option, or is longer than Linux allows, before asking sudo" {
  for iface in --help -x abcdefghijklmno+; do
    run "$openPort" 8080 1h --interface "$iface"
    assert_failure 1
    assert_output --partial "invalid interface '$iface'"
  done
  assert_equal "$(cat "$SUDO_LOG")" ""
}

@test "refuses to open anything when the firewall has no nixos-fw chain" {
  NO_NIXOS_FW=1 run "$openPort" 8080 1h --interface tailscale0
  assert_failure 1
  assert_output --partial "'nixos-fw' chain not found"
}
