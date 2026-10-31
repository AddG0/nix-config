# NOTE: Close Zen Browser before rebuilding!
# Spaces are applied via an activation script that may fail if Zen is running.
# See: https://github.com/0xc000022070/zen-browser-flake#spaces
{
  pkgs,
  lib,
  config,
  ...
}: let
  inherit (config.stylix.fonts) monospace sansSerif;
  # The key in Linux's Alt position; on macOS that's Command, while Option is OmniWM's Super.
  altPosition =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "meta"
    else "alt";
in {
  imports = [
    ./tridactyl.nix
  ];

  stylix.targets.zen-browser.profileNames = ["default"];

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;
    icon = lib.mkIf pkgs.stdenv.hostPlatform.isLinux ./icons/zen-catppuccin-mocha-mauve.svg;
    languagePacks = ["en-US"];
    policies = import ./policies-config.nix;

    profiles.default = {
      settings = {
        # Without this, quitting Zen can wipe zen-live-folders.jsonlz4 on save.
        "zen.window-sync.enabled" = true;
        # This syncs all my tabs again like it used to
        "zen.window-sync.sync-only-pinned-tabs" = false;
        # Workspaces
        "zen.workspaces.disabled_for_testing" = false;
        "zen.workspaces.hide-deactivated-workspaces" = false;
        "zen.workspaces.continue-where-left-off" = true;
        "zen.workspaces.natural-scroll" = true;
        # UI
        "zen.view.sidebar-expanded" = true; # Full expanded sidebar when visible
        "zen.view.use-single-toolbar" = false;
        "zen.welcome-screen.seen" = true;
        "zen.urlbar.behavior" = "float";
        # Tab switching (MRU Ctrl+Tab)
        "browser.ctrlTab.sortByRecentlyUsed" = true;
        # Scrolling
        "general.autoScroll" = true;
        # Disable Caret Browsing (F7 prompt)
        "accessibility.browsewithcaret" = false;
        "accessibility.warn_on_browsewithcaret" = false;
      };

      userContent = ''
        @-moz-document url-prefix("http") {
          body, button, input, select, textarea {
            font-family: "${sansSerif.name}" !important;
          }

          code, kbd, pre, samp {
            font-family: "${monospace.name}" !important;
          }
        }
      '';

      mods = [
        "253a3a74-0cc4-47b7-8b82-996a64f030d5" # Floating History
        "4ab93b88-151c-451b-a1b7-a1e0e28fa7f8" # No Sidebar Scrollbar
        "7190e4e9-bead-4b40-8f57-95d852ddc941" # Tab title fixes
        # "803c7895-b39b-458e-84f8-a521f4d7a064" # Hide Inactive Workspaces
        "906c6915-5677-48ff-9bfc-096a02a72379" # Floating Status Bar
        # "a6335949-4465-4b71-926c-4a52d34bc9c0" # Better Find Bar
        # "c6813222-6571-4ba6-8faf-58f3343324f6" # Disable Rounded Corners
        "c8d9e6e6-e702-4e15-8972-3596e57cf398" # Zen Back Forward
        "cb15abdb-0514-4e09-8ce5-722cf1f4a20f" # Hide Extension Name
        "d8b79d4a-6cba-4495-9ff6-d6d30b0e94fe" # Better Active Tab
        "e122b5d9-d385-4bf8-9971-e137809097d0" # No Top Sites
        "f7c71d9a-bce2-420f-ae44-a64bd92975ab" # Better Unloaded Tabs
        "fd24f832-a2e6-4ce9-8b19-7aa888eb7f8e" # Quietify
      ];

      extensions.packages = with pkgs.firefox-addons; [
        ublock-origin
        onepassword-password-manager
        tampermonkey
        stylus # Catppuccin: userstyles.catppuccin.com/getting-started/usage → download import.json → Stylus Settings → Backup → Import
        darkreader
        steam-database # SteamDB (steamdb.info) price/data overlay on Steam store
        youtube-auto-hd-fps # Force highest available quality on every YouTube video
      ];

      search = import ./search-config.nix {inherit pkgs;};

      keyboardShortcutsVersion = 21;
      keyboardShortcuts =
        [
          {
            id = "key_quitApplication";
            disabled = true;
          }
          # Free up Ctrl+Shift+Tab for MRU tab switching
          {
            id = "key_showAllTabs";
            disabled = true;
          }
          {
            id = "zen-compact-mode-toggle";
            key = "m";
            modifiers.control = true;
            modifiers.shift = true;
          }
          {
            id = "zen-copy-url";
            key = "c";
            # accel, not control: Karabiner turns Ctrl+Shift+C into Cmd+Shift+C on macOS.
            modifiers.accel = true;
            modifiers.shift = true;
          }
          # Workspace prev/next (Alt+,/.)
          {
            id = "zen-workspace-backward";
            key = ",";
            modifiers.${altPosition} = true;
          }
          {
            id = "zen-workspace-forward";
            key = ".";
            modifiers.${altPosition} = true;
          }
          # Prefer Tridactyl's vim binds over Zen's: free Ctrl+D/U (half page)
          # and Ctrl+F/B (full page) for scrolling. Native find moves to
          # Ctrl+Shift+F; view-source and bookmarks-sidebar shortcuts dropped.
          {
            id = "addBookmarkAsKb";
            disabled = true;
          }
          {
            id = "key_viewSource";
            disabled = true;
          }
          {
            id = "key_find";
            key = "f";
            modifiers = {
              accel = true;
              shift = true;
            };
          }
          {
            id = "viewBookmarksSidebarKb";
            disabled = true;
          }
        ]
        # Settings and stop-loading hold Cmd+,/. on macOS, which the workspace binds above take.
        ++ lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
          {
            id = "key_preferencesCmdMac";
            disabled = true;
          }
          {
            id = "key_stop_mac";
            disabled = true;
          }
        ];
    };
  };

  # mkBefore so the tag lands before its consumers — Hyprland applies rules in order.
  wayland.windowManager.hyprland.settings.windowrule = lib.mkBefore [
    "tag +browser, match:class ^(zen|zen-alpha|zen-beta)$"
  ];

  # 1Password claims Cmd+. (workspace forward) on macOS; back to Ctrl+. as on Linux. Extension "Ctrl" is Command here, "MacCtrl" is Control.
  home.activation.zenOnePasswordShortcut = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (lib.hm.dag.entryAfter ["writeBoundary"] (let
    profileDir = "${config.programs.zen-browser.profilesPath}/${config.programs.zen-browser.profiles.default.path}";
    settings = "${profileDir}/extension-settings.json";
  in ''
    (
      id=${lib.escapeShellArg pkgs.firefox-addons.onepassword-password-manager.addonId}
      if /usr/bin/pgrep -xq zen; then echo "zen: quit Zen and switch again, or it keeps 1Password on Cmd+." >&2; fi
      installDate=$(${lib.getExe pkgs.jq} --arg id "$id" '[.addons[]? | select(.id == $id) | .installDate][0] // 0' ${lib.escapeShellArg "${profileDir}/extensions.json"} 2>/dev/null || echo 0)
      current='{"version":3}'
      if [ -s ${lib.escapeShellArg settings} ]; then current=$(cat ${lib.escapeShellArg settings}); fi
      merged=$(${lib.getExe pkgs.jq} -c --arg id "$id" --argjson date "$installDate" '
        .commands._execute_browser_action.precedenceList =
          ([.commands._execute_browser_action.precedenceList[]? | select(.id != $id)]
           + [{id: $id, installDate: $date, value: {shortcut: "MacCtrl+Period"}, enabled: true}])
      ' <<<"$current") && [ -n "$merged" ] || { echo "zen: invalid JSON in ${settings}" >&2; exit 1; }
      if [ "$merged" != "$(${lib.getExe pkgs.jq} -c . <<<"$current")" ]; then
        tmp=$(mktemp)
        printf '%s\n' "$merged" >"$tmp"
        run install -Dm600 -T "$tmp" ${lib.escapeShellArg settings}
        rm -f "$tmp"
      fi
    )
  ''));

  # setAsDefaultBrowser only writes xdg.mimeApps; macOS needs LaunchServices. No-op (no prompt) when already default.
  home.activation.zenDefaultBrowser = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (lib.hm.dag.entryAfter ["writeBoundary"] ''
    run ${lib.getExe pkgs.defaultbrowser} zen
  '');
}
