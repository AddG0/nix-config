{pkgs, ...}: let
  inherit (pkgs.playwright-driver) browsers;
  playwright-wrapper = pkgs.writeShellScript "playwright-mcp" ''
    export PATH="${pkgs.nodejs}/bin:$PATH"
    export PLAYWRIGHT_BROWSERS_PATH="${browsers}"
    export PLAYWRIGHT_SKIP_VALIDATE_HOST_REQUIREMENTS=true
    export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
    PROFILE_DIR="''${XDG_DATA_HOME:-$HOME/.local/share}/playwright-mcp/profiles"
    mkdir -p "$PROFILE_DIR"
    # Resolve chromium dynamically — the revision in playwright-driver drifts
    # across nixpkgs bumps (e.g. chromium-1200 → chromium-1217).
    CHROME_BIN=("${browsers}"/chromium-*/chrome-linux64/chrome)
    if [ ! -x "''${CHROME_BIN[0]}" ]; then
      echo "playwright-mcp: no chromium binary found under ${browsers}" >&2
      exit 1
    fi
    npx -y @playwright/mcp@latest \
      --browser chromium \
      --executable-path "''${CHROME_BIN[0]}" \
      --user-data-dir "$PROFILE_DIR"
  '';
in {
  programs.code-assistant-profiles.addons.browser-mcp = {
    mcpServers.playwright.command = "${playwright-wrapper}";
  };
}
