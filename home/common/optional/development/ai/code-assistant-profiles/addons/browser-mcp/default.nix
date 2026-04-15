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
}
