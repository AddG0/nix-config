# nixpkgs trails claude-code's near-daily releases. Refresh:
# curl -fsSL https://downloads.claude.ai/claude-code-releases/$(curl -fsSL https://downloads.claude.ai/claude-code-releases/latest)/manifest.zst.json -o overlays/common/development/claude-code/manifest.zst.json
_: _final: prev: let
  manifest = prev.lib.importJSON ./manifest.zst.json;
in {
  # Conditional inside the value, not the attrset: making the overlay's shape
  # depend on a package eval recurses through nixpkgs' by-name overlay.
  claude-code =
    if prev.lib.versionOlder prev.claude-code.version manifest.version
    then prev.claude-code.override {inherit manifest;}
    else prev.claude-code;
}
