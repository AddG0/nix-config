{pkgs, ...}: let
  credDir = "\${XDG_CONFIG_HOME:-$HOME/.config}/google-workspace-mcp";
  workspace-mcp-wrapper = pkgs.writeShellScript "workspace-mcp" ''
    export PATH="${pkgs.uv}/bin:$PATH"
    CRED_DIR="${credDir}"
    for f in "$CRED_DIR/client-id" "$CRED_DIR/client-secret"; do
      if [ ! -f "$f" ]; then
        echo "Missing credential: $f" >&2
        echo "Create it with: mkdir -p \"$CRED_DIR\" && echo 'your-value' > \"$f\" && chmod 600 \"$f\"" >&2
        exit 1
      fi
    done
    export GOOGLE_OAUTH_CLIENT_ID="$(cat "$CRED_DIR/client-id")"
    export GOOGLE_OAUTH_CLIENT_SECRET="$(cat "$CRED_DIR/client-secret")"
    uvx workspace-mcp --single-user
  '';
in {
  mcpServers.google-workspace.command = "${workspace-mcp-wrapper}";
}
