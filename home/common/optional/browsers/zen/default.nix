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

  stylix.targets.zen-browser.profileNames = ["default"];

  programs.zen-browser = {
    enable = true;
    suppressXdgMigrationWarning = true;
    icon = ./icons/zen-catppuccin-mocha-mauve.svg;
    languagePacks = ["en-US"];
    policies = import ./policies-config.nix;

    profiles.default = rec {
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
        darkreader
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

      spacesForce = true;
      pinsForce = true;
      pins = {
        "YouTube" = {
          id = "c02f1740-1a97-41bc-b843-d54651be4e43";
          url = "https://www.youtube.com";
          position = 1000;
          isEssential = true;
        };
        "Gmail" = {
          id = "a654602c-37c8-4ae4-aca0-11d2450c7367";
          url = "https://mail.google.com";
          position = 2000;
          isEssential = true;
        };
        "Google Calendar" = {
          id = "98ae1f6b-f9e9-4820-b3e3-17d09244a482";
          url = "https://calendar.google.com";
          position = 3000;
          isEssential = true;
        };
        "JIRA" = {
          id = "1de5232d-c7cf-4c20-ac7f-62362ea4fa16";
          url = "https://webshopapps.atlassian.net/jira/software/c/projects/ENG26/boards/192?assignee=62b03e83566f3e7b0a8df8f8";
          position = 4000;
          workspace = spaces."Work".id;
        };
        "GitLab" = {
          id = "00427b2d-242d-4fa2-8b92-08f76b23bbc3";
          url = "https://gitlab.com/ShipperHQ";
          position = 5000;
          workspace = spaces."Work".id;
        };
        "Home Assistant" = {
          id = "e9509332-f744-4346-b83a-571592a064c1";
          url = "https://home-assistant.addg0.com";
          position = 6000;
          workspace = spaces."Main".id;
        };
      };

      # Icons: chrome://browser/skin/zen-icons/selectable/{name}.svg
      # Full list: unzip -l $(nix eval .#homeConfigurations.addg@demon.config.programs.zen-browser.package --raw)/lib/zen/browser/omni.ja | grep selectable
      spaces = {
        "Main" = {
          id = "a1b2c3d4-e5f6-4a7b-8c9d-0e1f2a3b4c5d";
          icon = "chrome://browser/skin/zen-icons/selectable/star.svg";
          position = 1000;
          container = containers."Personal".id;
        };
        "Work" = {
          id = "f6e5d4c3-b2a1-4987-6543-210fedcba987";
          icon = "chrome://browser/skin/zen-icons/selectable/briefcase.svg";
          position = 2000;
          container = containers."Work".id;
        };
      };

      keyboardShortcutsVersion = 16;
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
