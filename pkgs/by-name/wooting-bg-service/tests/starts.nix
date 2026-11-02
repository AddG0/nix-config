# The service starts: its AppImage finds every library its bundled ones link, which building it never checks.
{
  runCommand,
  wooting-bg-service,
}:
runCommand "wooting-bg-service-starts" {} ''
  export HOME=$TMPDIR
  # Panics later without D-Bus or a keyboard; only reaching its own startup line matters here.
  timeout 5 ${wooting-bg-service}/bin/wooting-bg-service >log 2>&1 || true
  if grep -q "error while loading shared libraries" log || ! grep -q "Starting Wooting Background Service" log; then
    echo "FAIL: wooting-bg-service did not reach startup:" >&2
    cat log >&2
    exit 1
  fi
  touch "$out"
''
