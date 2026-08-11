# Prism Launcher Module

Declarative Minecraft modpack management using [packwiz](https://packwiz.infra.link/) and home-manager.

## Overview

This module creates Prism Launcher instances from packwiz modpacks defined in your nix config. Features:

- **Auto-updating mods** - packwiz-installer syncs mods on each launch
- **Version auto-detection** - MC and loader versions read from pack.toml
- **Declarative settings** - keybinds, options synced across machines
- **Custom icons** - use any image file as instance icon
- **Instance groups** - organize instances in Prism Launcher
- **JVM args** - per-instance memory and JVM settings
- **Orphan cleanup** - removed modpacks are auto-deleted

## Quick Start

### 1. Create a modpack

```bash
mkdir -p ~/nix-config/home/common/optional/gaming/minecraft/modpacks/my-pack
cd ~/nix-config/home/common/optional/gaming/minecraft/modpacks/my-pack

# Initialize packwiz
packwiz init --name "My Pack" --mc-version 1.20.1 --modloader fabric --fabric-version 0.16.10

# Add some mods
packwiz modrinth add sodium lithium starlight
```

### 2. Configure in nix

```nix
# home/common/optional/gaming/minecraft/default.nix
{...}: {
  programs.prismlauncher = {
    enable = true;
    modpacks = {
      "my-pack" = {
        source = ./modpacks/my-pack;
        # Versions auto-detected from pack.toml
        icon = ./icons/my-pack.png;  # Or "diamond" for built-in
        group = "Modded";
        minMemory = 2048;
        maxMemory = 8192;
      };
    };
  };
}
```

### 3. Apply

```bash
just r
```

Launch Prism Launcher - your instance appears ready to play.

## Module Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable Prism Launcher with packwiz |
| `package` | package | pkgs.prismlauncher | Prism Launcher package |
| `cleanupOrphans` | bool | true | Remove instances no longer in config |
| `onPrismRunning` | enum | "ignore" | ignore/skip/close/force-close when Prism is running |
| `modpacks.<name>.source` | path | required | Path to packwiz modpack directory |
| `modpacks.<name>.mcVersion` | string | null | MC version (auto-detected if null) |
| `modpacks.<name>.loader` | enum | null | fabric/quilt/forge/neoforge (auto-detected) |
| `modpacks.<name>.loaderVersion` | string | null | Loader version (auto-detected) |
| `modpacks.<name>.icon` | string/path | "default" | Built-in icon key or path to image |
| `modpacks.<name>.group` | string | null | Instance group in Prism |
| `modpacks.<name>.javaArgs` | string | null | JVM arguments |
| `modpacks.<name>.minMemory` | int | null | Minimum heap in MiB |
| `modpacks.<name>.maxMemory` | int | null | Maximum heap in MiB |

## Activating While Prism Is Running

Prism reads `instance.cfg` once at startup and rewrites the whole file from
memory whenever any setting changes. Activating under a live launcher therefore
looks like it worked and then silently reverts. `onPrismRunning` decides what to
do about it:

```nix
programs.prismlauncher.onPrismRunning = "close";
```

| Value | Behaviour |
|-------|-----------|
| `ignore` | Write anyway (default; the old behaviour) |
| `skip` | Leave instances alone, apply on the next activation |
| `close` | Quit Prism first — unless a game is running, then skip |
| `force-close` | Quit Prism first even mid-game |

`close` and `force-close` send SIGTERM and wait up to 10s. Prism flushes its
settings on a clean quit, so terminating it politely avoids racing the writes
that follow. Under `--dry-run` nothing is killed.

## Memory

Prism's launcher-wide default is 512 MiB min / 4096 MiB max. Set `minMemory` /
`maxMemory` to override it per instance:

```nix
"my-pack" = {
  source = ./modpacks/my-pack;
  minMemory = 2048;
  maxMemory = 8192;
};
```

Setting either one flips Prism's `OverrideMemory` gate, which covers both keys.
The module always writes both — with the gate on, a missing key resolves to
Prism's compiled default rather than your launcher-wide setting, so leaving one
out would silently reset it. Prefer these over `-Xmx`/`-Xms` in `javaArgs`, so
the values show up in Prism's settings UI.

## Packwiz Commands

All commands run from your modpack directory.

### Mods

```bash
# Add from Modrinth (preferred)
packwiz modrinth add sodium

# Add from CurseForge
packwiz curseforge add jei

# Search for mods
packwiz modrinth add --search "optimization"

# Remove a mod
packwiz remove sodium

# Update all mods
packwiz update --all -y

# Update specific mod
packwiz update sodium
```

### Resource Packs

```bash
# From Modrinth
packwiz modrinth add "faithful-32x" --meta-folder resourcepacks

# From URL (GitHub, etc)
packwiz url add "MyPack" "https://example.com/pack.zip" --meta-folder resourcepacks
```

### Maintenance

```bash
# Refresh index after manual changes
packwiz refresh

# List all mods
ls mods/*.pw.toml | xargs -I{} basename {} .pw.toml
```

## Settings & Keybinds

Create `overrides/options.txt` in your modpack:

```
mouseSensitivity:0.5
key_key.sprint:key.keyboard.r
key_key.togglePerspective:key.keyboard.f5
narrator:0
autoJump:false
```

Packwiz syncs these to the instance on launch. Use the [yosbr](https://modrinth.com/mod/yosbr) mod for config merging (configs go in `config/yosbr/`).

## File Structure

```
modpacks/my-pack/
├── pack.toml              # Modpack metadata (name, versions)
├── index.toml             # Auto-generated file index
├── mods/
│   ├── sodium.pw.toml     # Mod metadata (hash + URL)
│   └── ...
├── resourcepacks/
│   └── ...
└── overrides/
    └── options.txt        # Custom settings
```

## Icons

### Built-in Icons

Prism includes these icon keys:
`default`, `bee`, `brick`, `chicken`, `creeper`, `diamond`, `dirt`, `enderman`, `enderpearl`, `flame`, `fox`, `gear`, `gold`, `grass`, `iron`, `meat`, `modrinth`, `planks`, `skeleton`, `steve`, `stone`, `tnt`

### Custom Icons

Use any image path:

```nix
icon = ./icons/my-pack.png;
icon = ../../assets/logo.jpg;
icon = /home/user/Pictures/icon.webp;
```

Supported formats: png, jpg, svg, ico, webp

## Changing Loader Version

Edit `pack.toml`:

```toml
[versions]
fabric = "0.18.4"
minecraft = "1.20.1"
```

Then:

```bash
packwiz refresh
just r
```

The loader version is automatically updated on rebuild.

## Troubleshooting

### Mods not updating

1. Run `packwiz refresh` in modpack directory
2. Run `just r`
3. Restart Prism Launcher
4. Launch instance (packwiz-installer runs on launch)

### Loader version conflicts

Check mod requirements:
```bash
packwiz modrinth add "mod-name" --search
```

Update loader in `pack.toml` and delete `mmc-pack.json`.

### Reset instance completely

```bash
rm -rf ~/.local/share/PrismLauncher/instances/my-pack
just r
```

## How It Works

1. **Build time**: Nix symlinks modpack files to `~/.local/share/packwiz/<name>/`
2. **Activation**: Creates Prism instance with `instance.cfg` pointing to packwiz
3. **Launch**: `packwiz-installer-bootstrap.jar` runs as PreLaunchCommand, syncing mods from the packwiz metadata
4. **Play**: Minecraft launches with all mods downloaded and ready

Mods aren't stored in the nix store - only `.pw.toml` metadata files. Actual mod jars are downloaded to the instance's mods folder on first launch.
