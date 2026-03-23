# Google Workspace MCP (taylorwilsdon/google_workspace_mcp)
# Gmail, Drive, Calendar, Docs, Sheets, Slides, Forms, Tasks, Chat, and more.
#
# Setup:
#   1. Go to https://console.cloud.google.com/apis/credentials
#   2. Create an OAuth 2.0 Client ID (type: "Desktop application")
#   3. Enable the APIs you need (Gmail, Sheets, Drive, Calendar, Docs, etc.)
#      Quick links at: https://github.com/taylorwilsdon/google_workspace_mcp#enable-required-apis
#   4. Store credentials:
#        mkdir -p ~/.config/google-workspace-mcp
#        echo 'your-client-id'     > ~/.config/google-workspace-mcp/client-id
#        echo 'your-client-secret' > ~/.config/google-workspace-mcp/client-secret
#        chmod 600 ~/.config/google-workspace-mcp/client-{id,secret}
#   5. On first run the server opens your browser for OAuth consent.
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

  settings.permissions.allow = [
    # Gmail
    "mcp__google-workspace__gmail_search"
    "mcp__google-workspace__gmail_read"
    "mcp__google-workspace__gmail_list_labels"
    # Calendar
    "mcp__google-workspace__calendar_list"
    "mcp__google-workspace__calendar_get_events"
    # Drive
    "mcp__google-workspace__drive_search"
    "mcp__google-workspace__drive_read"
    "mcp__google-workspace__drive_list"
    # Sheets
    "mcp__google-workspace__sheets_read"
    "mcp__google-workspace__sheets_list"
    # Docs
    "mcp__google-workspace__docs_read"
  ];
}
