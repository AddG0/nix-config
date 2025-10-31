{pkgs, ...}: {
  programs.floorp = {
    enable = true;

    profiles = {
      default = {
        name = "Default";
        isDefault = true;

        # Privacy and security settings
        settings = {
          # Privacy & Tracking Protection
          "privacy.trackingprotection.enabled" = true;
          "privacy.trackingprotection.socialtracking.enabled" = true;
          "privacy.donottrackheader.enabled" = true;
          "dom.security.https_only_mode" = true;
          "network.cookie.cookieBehavior" = 1; # Block third-party cookies

          # Interface & Behavior
          "browser.startup.homepage" = "about:home";
          "browser.newtabpage.enabled" = false;
          "browser.tabs.loadInBackground" = true;
          "browser.urlbar.suggest.searches" = false;
          "browser.urlbar.suggest.topsites" = false;

          # Performance
          "browser.cache.disk.enable" = false;
          "browser.sessionstore.privacy_level" = 2;
          "media.eme.enabled" = false; # Disable DRM

          # Downloads
          "browser.download.useDownloadDir" = true;
          "browser.download.alwaysOpenPanel" = false;

          # Disable telemetry
          "datareporting.healthreport.uploadEnabled" = false;
          "datareporting.policy.dataSubmissionEnabled" = false;
          "toolkit.telemetry.enabled" = false;
          "toolkit.telemetry.unified" = false;

          # Enable all extensionsc
          "extensions.autoDisableScopes" = 0;
        };

        # Extension management and configuration
        extensions = {
          packages = [
            pkgs.firefox-addons.ublock-origin
            pkgs.firefox-addons.onepassword-password-manager
          ];
          settings = {
            "addons-search-detection@mozilla.com".settings = {};
            "floorp-actions@floorp.ablaze.one".settings = {};
            "floorp-system@floorp.ablaze.one".settings = {};
            "formautofill@mozilla.org".settings = {};
            "official-site-ua@floorp.ablaze.one".settings = {};
            "paxmod@numirias".settings = {};
            "pictureinpicture@mozilla.org".settings = {};
            "default-theme@mozilla.org".settings = {};
            "webcompat@mozilla.org".settings = {};
            "webpanel-ua@floorp.ablaze.one".settings = {};
            "d634138d-c276-4fc8-924b-40a0ea21d284".settings = {};
          };
        };

        # Bookmarks
        # bookmarks = {
        #   bookmarks = [
        #     {
        #       name = "Development";
        #       toolbar = true;
        #       bookmarks = [
        #         {
        #           name = "NixOS Manual";
        #           url = "https://nixos.org/manual/nixos/stable/";
        #         }
        #         {
        #           name = "Home Manager Options";
        #           url = "https://mynixos.com/home-manager/options";
        #         }
        #         {
        #           name = "Nix Packages";
        #           url = "https://search.nixos.org/packages";
        #         }
        #       ];
        #     }
        #     {
        #       name = "GitHub";
        #       url = "https://github.com";
        #     }
        #     {
        #       name = "NixOS Discourse";
        #       url = "https://discourse.nixos.org";
        #     }
        #   ];
        # };

        # Custom CSS for browser UI
        userChrome = ''
          /* Hide tab bar when using sidebar/tree tabs if needed */
          /*
          #TabsToolbar {
            visibility: collapse !important;
          }
          */

          /* Customize navbar */
          #nav-bar {
            border: none !important;
            box-shadow: none !important;
          }

          /* Minimal context menus */
          menupopup > menuitem,
          menupopup > menu {
            padding-block: 4px !important;
          }

          /* Hide unnecessary UI elements */
          #pocket-button,
          #fxa-toolbar-menu-button {
            display: none !important;
          }
        '';

        # # Custom CSS for web content
        # userContent = ''
        #   /* Dark scrollbars for better consistency */
        #   * {
        #     scrollbar-width: thin;
        #     scrollbar-color: #484848 #2b2b2b;
        #   }

        #   /* Improve readability on some sites */
        #   @media (prefers-color-scheme: dark) {
        #     input, textarea, select {
        #       background-color: #2b2b2b !important;
        #       color: #ffffff !important;
        #       border: 1px solid #484848 !important;
        #     }
        #   }
        # '';

        # Container tabs for better organization
        containers = {
          "Personal" = {
            color = "blue";
            icon = "fingerprint";
            id = 1;
          };
          "Work" = {
            color = "orange";
            icon = "briefcase";
            id = 2;
          };
          "Development" = {
            color = "green";
            icon = "chill";
            id = 3;
          };
          "Shopping" = {
            color = "pink";
            icon = "cart";
            id = 4;
          };
        };
      };
    };
  };
}
