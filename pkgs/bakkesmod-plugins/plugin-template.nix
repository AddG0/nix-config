# Template for adding new BakkesMod plugins
#
# To add a new plugin:
# 1. Create a new directory: pkgs/common/bakkesmod-plugins/PLUGIN_NAME/
# 2. Copy this template to package.nix in that directory
# 3. Update the values below
# 4. Find the plugin ID from https://bakkesplugins.com/plugins/view/PLUGIN_ID
# 5. Build to get sha256: `NIXPKGS_ALLOW_UNFREE=1 nix build --impure .#legacyPackages.x86_64-linux.bakkesmod-plugins.PLUGIN_NAME`
# 6. Copy the sha256 from the error message
#
# The builder will automatically:
# - Fetch the CDN URL from the BakkesPlugins API
# - Download and extract the plugin zip
# - Install all files (DLLs, settings, assets)

{ callPackage }:

let
  mkBakkesModPlugin = callPackage ../mk-bakkesmod-plugin.nix {};
in
mkBakkesModPlugin {
  pname = "PluginName";      # Name of the plugin (for identification)
  version = "1.0.0";         # Plugin version (from the website)
  pluginId = "123";          # Numeric ID from bakkesplugins.com URL
  sha256 = "";               # Will be filled after first build attempt
  description = "Plugin description";

  # Optional: additional meta attributes
  meta = {
    homepage = "https://github.com/...";
  };
}