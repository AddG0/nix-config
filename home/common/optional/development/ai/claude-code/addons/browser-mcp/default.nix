# Browser automation via Playwright MCP (headless Chromium, no extension needed)
{pkgs, ...}: let
  inherit (pkgs.playwright-driver) browsers;
  playwright-wrapper = pkgs.writeShellScript "playwright-mcp" ''
    export PATH="${pkgs.nodejs}/bin:$PATH"
    export PLAYWRIGHT_BROWSERS_PATH="${browsers}"
    export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
    export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
    PROFILE_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/playwright-mcp/profiles"
    mkdir -p "$PROFILE_DIR"
    npx -y @playwright/mcp@latest \
      --browser chromium \
      --executable-path "${browsers}/chromium-1200/chrome-linux64/chrome" \
      --user-data-dir "$PROFILE_DIR"
  '';
in {
  mcpServers.playwright.command = "${playwright-wrapper}";

  settings.permissions.allow = [
    "mcp__playwright__browser_navigate"
    "mcp__playwright__browser_go_back"
    "mcp__playwright__browser_go_forward"
    "mcp__playwright__browser_wait"
    "mcp__playwright__browser_press_key"
    "mcp__playwright__browser_snapshot"
    "mcp__playwright__browser_click"
    "mcp__playwright__browser_drag"
    "mcp__playwright__browser_hover"
    "mcp__playwright__browser_type"
    "mcp__playwright__browser_console_logs"
    "mcp__playwright__browser_screenshot"
  ];
}
