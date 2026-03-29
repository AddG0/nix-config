# Schematics

Litematica schematics installed into `.minecraft/schematics/` on instance launch.

## Keybinds

| Key | Action |
|-----|--------|
| `\` | Open Litematica main menu |
| `\ + L` | Material list |
| `\ + P` | Schematic placements |
| `\ + S` | Selection manager |
| `\ + V` | Schematic verifier |
| `\ + C` | Settings |
| `\ + R` | Toggle all rendering |
| `\ + G` | Toggle schematic rendering |
| `\ + T` | Toggle tool item |
| `\ + A` | Add selection box |
| `\ + Page Up/Down` | Layer mode next/previous |
| `Ctrl + Scroll` | Cycle tool modes (while holding stick) |
| `Alt + Scroll` | Nudge/move selection |
| `Ctrl + \` | Cycle paste replace behavior |
| `Middle click` | Select placement (while holding stick, ~200 block range) |
| `Alt + Middle click` | Store block state for edit mode |
| `Numpad *` | Area settings |
| `Numpad -` | Placement settings |

## Tool Item (Stick)

Litematica uses a **stick** as its tool item. Hold it to access tool modes and operations.

The tool HUD appears bottom-left when active, showing the current mode and selected placement.

### Tool Modes

Cycle modes with `Ctrl + Scroll` while holding the stick:

| Mode | Description |
|------|-------------|
| **Schematic Placement** | Default — position/rotate loaded schematics |
| **Area Selection** | Select regions for creating new schematics |
| **Paste Schematic in World** | Paste all blocks instantly (creative only) |
| **Edit Schematic** | Modify blocks within a loaded schematic |
| **Delete** | Remove blocks in selected area |
| **Fill** | Fill selected area with a block |
| **Replace** | Replace one block type with another in area |

## Loading a Schematic

1. Press `\` to open the main menu
2. Click **Schematic Browser**
3. Select a `.litematic` file from the list
4. Click **Load Schematic**

## Placing a Schematic (Hologram)

1. Press `\ + P` to open schematic placements
2. Click **Configure** on your loaded schematic
3. Adjust position, rotation, or mirror as needed
4. The hologram renders in-world showing where blocks go

## Moving a Placement

While holding the stick with a placement selected:

- **`Alt + Scroll`** — nudge the placement in the direction you're facing
- **Middle click** — select/grab the placement you're looking at

For precise positioning: `\ + P` > select placement > **Configure** > adjust X/Y/Z, rotation, or mirror.

## Pasting a Schematic (Creative Only)

Instantly places all blocks — no items consumed.

1. Switch to **Creative mode**
2. Hold the **stick** (tool item) and `Ctrl + Scroll` to **Paste Schematic in World** mode
3. Select the placement — middle-click while looking at it, or pick it in `\ + P`
4. The tool HUD (bottom-left) should show the placement name
5. Press **`\ + Enter`** to paste

### Paste Replace Behavior

Cycle with `Ctrl + M`:

| Mode | Behavior |
|------|----------|
| **None** | Only place where air exists |
| **With non-air** | Non-air schematic blocks replace existing blocks |
| **All** | Replace everything that differs from schematic |

## Building with a Schematic (Survival)

- **Easy Place mode** (enabled by default) — right-click a ghost block and it auto-places the correct block from your inventory
- **Layer mode** (`\ + Page Up/Down`) — render one layer at a time for easier building
- **Material list** (`\ + L`) — shows all blocks needed and quantities
- **Verifier** (`\ + V`) — scans and highlights blocks:
  - Red = wrong block
  - Orange = missing block
  - Green = extra block (not in schematic)

## Creating a Schematic

1. Hold the stick and `Ctrl + Scroll` to **Area Selection** mode
2. Left-click to set corner 1, right-click to set corner 2
3. Press `\ + S` to open the selection manager
4. Click **Save Schematic**
5. Name it and save — goes to `.minecraft/schematics/`

## Edit Schematic Mode

For modifying blocks inside a loaded schematic without affecting the world.

1. `Ctrl + Scroll` to **Edit Schematic** mode while holding the stick
2. Assign hotkeys in `M` > Configuration > Hotkeys (search `schematicEdit`)
3. Operations include replace block, replace all, break all except, directional replace
4. **Important:** switch out of this mode when done, or normal block placement will keep editing the schematic

To use specific block states (e.g. waterlogged, open trapdoors):
1. Place the block correctly in the world
2. `Alt + Middle click` to store that state
3. Use empty main hand in edit operations to apply the stored state

## Included Schematics

### Tunnelbores (afterfive_s)

| Schematic | Dimension | Type |
|---|---|---|
| `1d-nether-tunnelbore.litematic` | Nether | 1-directional |
| `1d-overworld-tunnelbore.litematic` | Overworld | 1-directional |
| `2d-nether-tunnelbore.litematic` | Nether | 2-directional |
