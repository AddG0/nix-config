# NOTE: Close Zen Browser before rebuilding!
# Spaces are applied via an activation script that may fail if Zen is running.
# See: https://github.com/0xc000022070/zen-browser-flake#spaces
{
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports =
    [
      inputs.zen-browser.homeModules.beta
    ]
    ++ lib.optionals pkgs.stdenv.hostPlatform.isLinux [
      ./xdg.nix
    ];

  programs.zen-browser = {
    enable = true;
    icon = ./icons/zen-catppuccin-mocha-mauve.svg;
    languagePacks = ["en-US"];
    policies = import ./policies-config.nix;

    profiles.default = {
      settings = {
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
      };

      mods = [
        "253a3a74-0cc4-47b7-8b82-996a64f030d5" # Floating History
        "4ab93b88-151c-451b-a1b7-a1e0e28fa7f8" # No Sidebar Scrollbar
        "7190e4e9-bead-4b40-8f57-95d852ddc941" # Tab title fixes
        # "803c7895-b39b-458e-84f8-a521f4d7a064" # Hide Inactive Workspaces
        "906c6915-5677-48ff-9bfc-096a02a72379" # Floating Status Bar
        "a6335949-4465-4b71-926c-4a52d34bc9c0" # Better Find Bar
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
        stylus # Catppuccin: userstyles.catppuccin.com → download import.json → Stylus Settings → Backup → Import
        leechblock-ng # Block time-wasting sites (youtube, reddit, etc) with time limits
      ];

      search = import ./search-config.nix {inherit pkgs;};

      containersForce = true;
      containers = {
        Personal = {
          color = "purple";
          icon = "fingerprint";
          id = 1;
        };
        Work = {
          color = "blue";
          icon = "briefcase";
          id = 2;
        };
      };

      # spacesForce = true;
      # spaces = {
      #   "Main" = {
      #     id = "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d";
      #     icon = "🏠";
      #     position = 1000;
      #     container = containers."Personal".id;
      #     theme = {
      #       type = "gradient";
      #       colors = [
      #         {
      #           red = 123;
      #           green = 56;
      #           blue = 58;
      #           algorithm = "analogous";
      #           type = "explicit-lightness";
      #           lightness = 35;
      #           position.x = 301;
      #           position.y = 176;
      #         }
      #       ];
      #       opacity = 0.8;
      #       texture = 0.5;
      #     };
      #   };
      #   "Work" = {
      #     id = "f6e5d4c3-b2a1-4987-6543-210fedcba987";
      #     icon = "💼";
      #     position = 2000;
      #     container = containers."Work".id;
      #     theme = {
      #       type = "gradient";
      #       colors = [
      #         {
      #           red = 56;
      #           green = 100;
      #           blue = 166;
      #           algorithm = "floating";
      #           type = "explicit-lightness";
      #         }
      #       ];
      #       opacity = 0.5;
      #       texture = 0.3;
      #     };
      #   };
      # };

      keyboardShortcutsVersion = 14;
      keyboardShortcuts = [
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
          modifiers.control = true;
          modifiers.shift = true;
        }
        # Workspace prev/next (Alt+,/.)
        {
          id = "zen-workspace-backward";
          key = ",";
          modifiers.alt = true;
        }
        {
          id = "zen-workspace-forward";
          key = ".";
          modifiers.alt = true;
        }
      ];
    };
  };
}
