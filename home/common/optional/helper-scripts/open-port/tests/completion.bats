# open-port's zsh completion, run by zsh's own completion system: what each position offers, from fake ip, ss and systemctl.

setup() {
  bats_load_library bats-support
  bats_load_library bats-assert

  mkdir -p "$BATS_TEST_TMPDIR/bin"
  fake ip <<'OUT'
1: lo: <LOOPBACK,UP> mtu 65536
2: enp8s0: <BROADCAST,UP> mtu 1500
3: tailscale0: <POINTOPOINT,UP> mtu 1280
4: veth1@if3: <BROADCAST> mtu 1500
OUT
  fake ss <<'OUT'
tcp LISTEN 0 4096 0.0.0.0:22 0.0.0.0:*
tcp LISTEN 0 4096 127.0.0.1:631 0.0.0.0:*
tcp LISTEN 0 4096 [::]:22 [::]:*
udp UNCONN 0 0 *:5353 *:*
tcp LISTEN 0 128 [::1]:8000 [::]:*
OUT
  fake systemctl <<'OUT'
close-port-tcp-8080.timer loaded active waiting Close tcp/8080 after 1h
close-port-udp-5353-on-wl\x2b.timer loaded active waiting Close udp/5353 on wl+ after 1h
OUT
}

# Installs a fake <command> that prints its standard input whenever it runs.
fake() { # <command>
  cat >"$BATS_TEST_TMPDIR/fake-$1.out"
  printf '#!/bin/sh\ncat %s\n' "$BATS_TEST_TMPDIR/fake-$1.out" >"$BATS_TEST_TMPDIR/bin/$1"
  chmod +x "$BATS_TEST_TMPDIR/bin/$1"
}

# What tab offers after <line>, one "[candidate] -- description" per line, sorted.
completes() { # <line>
  zsh -f "$captureCompletion" "$openPortShare/zsh/site-functions" "$BATS_TEST_TMPDIR/bin:$PATH" "$1" | LC_ALL=C sort
}

@test "offers the ports something listens on beyond loopback as the port to open" {
  run completes "open-port "
  assert_success
  assert_output "$(printf '%s\n' '[22] -- tcp listener' '[5353] -- udp listener')"
}

@test "offers a duration after the port to open, then a protocol" {
  run completes "open-port 8080 "
  assert_output --partial "[1h] -- one hour"
  run completes "open-port 8080 1h "
  assert_output "$(printf '%s\n' '[tcp] -- the default' '[udp]')"
}

@test "offers the ports open-port has a close timer for after --close, with their protocol and interface" {
  run completes "open-port --close "
  assert_output "$(printf '%s\n' '[5353] -- udp on wl+' '[8080] -- tcp on every interface')"
  run completes "open-port --close 8080 "
  assert_output "$(printf '%s\n' '[tcp] -- the default' '[udp]')"
}

@test "offers each interface ip lists, and wildcards for every Ethernet and every Wi-Fi interface, after -i wherever it comes" {
  run completes "open-port 8080 1h -i "
  assert_output --partial "[en+] -- every Ethernet interface"
  assert_output --partial "[wl+] -- every Wi-Fi interface"
  assert_output --partial "[veth1]"
  assert_output --partial "[tailscale0]"
}

@test "offers --close and --status only as the first argument, as open-port reads them" {
  run completes "open-port -"
  assert_output --partial "[--close]"
  run completes "open-port 8080 -"
  refute_output --partial "--close"
  refute_output --partial "--status"
  assert_output --partial "[--interface"
}
