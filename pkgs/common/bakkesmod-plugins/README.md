# BakkesMod Plugins for NixOS

This directory contains BakkesMod plugins packaged for Nix.

## How to use plugins

1. Enable plugins in `home/common/optional/gaming/bakkesmod.nix`:
   ```nix
   plugins = [
     pkgs.bakkesmod-plugins.ingamerank
     # Add more plugins here
   ];
   ```

2. Rebuild your configuration
3. Plugins will be automatically installed when you launch Rocket League

## Adding new plugins

1. Find the plugin on https://bakkesplugins.com
2. Note the plugin ID from the URL (e.g., `/plugins/view/282`)
3. Create a new directory: `pkgs/common/bakkesmod-plugins/PLUGIN_NAME/`
4. Copy `plugin-template.nix` to `package.nix` in that directory
5. Update the values:
   - `pname`: The plugin DLL name (without .dll)
   - `version` and `pluginId`: The numeric ID from bakkesplugins.com
   - `description`: A brief description

6. Build to get the sha256 hash:
   ```bash
   nix build .#bakkesmod-plugins.PLUGIN_NAME
   ```
   The build will fail with the correct sha256 - add it to package.nix

7. Rebuild and add to your plugins list

## Available plugins

- `ingamerank` - Shows player ranks in-game scoreboards

## Structure

- `mk-bakkesmod-plugin.nix` - Builder function for plugins
- `*/package.nix` - Individual plugin definitions
- `plugin-template.nix` - Template for new plugins