#
# First-time setup (once per machine):
#
#   1. Get a Home Assistant access token
#      Open your Home Assistant in a browser (same URL you use day-to-day —
#      e.g. http://homeassistant.local:8123, your LAN IP, or Nabu Casa URL).
#      Click your profile avatar (bottom-left) → Security tab →
#      Long-Lived Access Tokens → Create Token. Copy it immediately.
#
#   2. Register this device
#        go-hass-agent-amd64 register
#      It will ask for the same HA URL and the token from step 1.
#
#   3. Start it
#        systemctl --user enable --now hass-agent
#
#   4. (Optional) Keep running without being logged in
#        sudo loginctl enable-linger $USER
#
#   5. (Optional) Enable MQTT controls — volume, suspend, lock, custom buttons
#        go-hass-agent-amd64 config --mqtt-server=tcp://broker:1883
#
_: {
  services.hassAgent.enable = true;
}
