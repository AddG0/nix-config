# Browser MCP addon - browser automation via Chrome extension
# Requires: https://chromewebstore.google.com/detail/browser-mcp-automate-your/bjfgambnhccakkhmkepdoekmckoijdlc
{pkgs, ...}: let
  browser-mcp-wrapper = pkgs.writeShellScript "browser-mcp" ''
    export PATH="${pkgs.nodejs}/bin:${pkgs.lsof}/bin:$PATH"
    npx -y @browsermcp/mcp@latest
  '';
in {
  mcpServers.browser-mcp.command = "${browser-mcp-wrapper}";

  settings.permissions.allow = [
    "mcp__browser-mcp__browser_navigate"
    "mcp__browser-mcp__browser_go_back"
    "mcp__browser-mcp__browser_go_forward"
    "mcp__browser-mcp__browser_wait"
    "mcp__browser-mcp__browser_press_key"
    "mcp__browser-mcp__browser_snapshot"
    "mcp__browser-mcp__browser_click"
    "mcp__browser-mcp__browser_drag"
    "mcp__browser-mcp__browser_hover"
    "mcp__browser-mcp__browser_type"
    "mcp__browser-mcp__browser_console_logs"
    "mcp__browser-mcp__browser_screenshot"
  ];

  memory.text = builtins.readFile ./memory.md;
}
