# Config Overrides

## client_side_anchors.json

Copied from live instance with the following changes:

- `introShown` set to `true` (default `false`) — suppresses the intro screen
- `autoUpdateTouched` set to `true` (default `false`) — suppresses the auto-update prompt

## inventoryhud.json

Copied from live instance with the following changes:

- `inv_toggle` set to `false` (default `true`) — disables inventory overlay on HUD

## modmenu.json

Copied from live instance with the following changes:

- `update_checker` set to `false` (default `true`) — mod versions come from packwiz
- `button_update_badge` set to `false` (default `true`) — hides the update badge

## replaymod.json

Copied from live instance with the following changes:

- `recording.indicator` set to `false` (default `true`) — the indicator overlaps MiniHUD

## sodium-extra-options.json

Copied from live instance with the following changes:

- `show_coords` set to `false` (default `true`) — MiniHUD already shows coordinates

## voicechat/voicechat-client.properties

Copied from live instance with the following changes:

- `hide_icons` set to `false` (default `true`) — starts in phase with MiniHUD, which shares the H toggle
- `disabled` set to `true` (default `false`) — starts with voice chat off

## xaero/minimap/profiles/default.cfg

Copied from live instance with the following changes:

- `display_minimap` set to `false` (default `true`) — hides minimap overlay by default

## xaero/world-map/client.cfg

Copied from live instance with the following changes:

- `max_loaded_regions` set to `1000` (default `300`) — keeps more of the map loaded
- `update_notifications` set to `false` (default `true`) — hides the update notice
